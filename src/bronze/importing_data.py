# %%
"""
Ingestao VNL feminina - Sportmicro API (bronze layer).

Fluxo:
    seasons-by-league (liga 75)
      -> para cada season: matches
      -> para cada match FINALIZADO: matches-statistics
      -> os times (paises) de cada match vem do proprio match -> teams
      -> para cada time: players-by-team (a ponte time -> jogadora)
      -> para cada jogadora: players (o detalhe da jogadora)

Cache: times e jogadoras nao mudam de uma rodada para outra, entao
antes de buscar o codigo le o que ja esta salvo em disco e so pede
a API o que ainda falta. Assim nao gastamos requisicao a toa.

Estatisticas: so buscamos (e guardamos) estatisticas de jogos com
status "finished". Jogo ao vivo tem estatistica PARCIAL - se a gente
salvasse, na proxima execucao o jogo ja estaria "finished" e o cache
pularia ele, congelando a estatistica incompleta para sempre.

Cada endpoint e salvo em seu proprio arquivo JSON dentro de bronze/.
"""

import json
import time
from pathlib import Path

import requests

from Key import key

# ---------------------------------------------------------------------------
#                                   CONFIG
# ---------------------------------------------------------------------------

BASE_URL = "https://volleyball.sportmicro.com/"
HEADERS = {"Authorization": f"Bearer {key}"}

LEAGUE_ID = 75      # Women's VNL
SEASON_IDS = None   # None = todas as seasons da liga; ou lista, ex: [103]

PAGE_LIMIT = 50     # quantas linhas pedimos por pagina
SLEEP = 0.1         # pausa entre requisicoes - a API tem limite de uso
TIMEOUT = 30        # segundos; sem timeout uma conexao ruim trava o script
MAX_TENTATIVAS = 3  # quantas vezes insistimos quando uma requisicao falha

OUT_DIR = Path("../../data/bronze/")
# parents=True cria tambem ../../data/ caso ela ainda nao exista
# (sem isso, o mkdir quebra em maquina nova ou repositorio recem-clonado)
OUT_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
#                                 REQUESTING
# ---------------------------------------------------------------------------

def get(endpoint, params=None):
    """
    Faz uma requisicao GET simples e devolve o JSON.

    Duas protecoes importantes:
      - timeout: sem ele, uma conexao ruim pode deixar o script
        pendurado para sempre, sem erro e sem resposta;
      - re-tentativas: falha passageira de rede (ou limite da API)
        nao derruba a ingestao inteira - esperamos um pouco e
        tentamos de novo antes de desistir.
    """
    url = f"{BASE_URL}{endpoint}"

    for tentativa in range(1, MAX_TENTATIVAS + 1):
        try:
            resp = requests.get(url,
                                headers=HEADERS,
                                params=params,
                                timeout=TIMEOUT)
            resp.raise_for_status()  # levanta erro se veio 4xx/5xx
            time.sleep(SLEEP)
            return resp.json()

        except requests.RequestException as erro:
            if tentativa == MAX_TENTATIVAS:
                raise  # ja insistimos o suficiente, deixa o erro subir

            espera = 2 * tentativa  # espera um pouco mais a cada falha
            print(f"  aviso: {endpoint} falhou ({erro}). "
                  f"Nova tentativa em {espera}s...")
            time.sleep(espera)


def paginate(endpoint, params=None):
    """
    Para endpoints com resposta longa: pede pagina por pagina
    (offset/limit) ate a API devolver uma pagina VAZIA.

    Tres cuidados que evitam dados incompletos ou duplicados:

      1. order fixo: sem ordenacao, o banco pode devolver as linhas
         em ordem diferente a cada pagina -> a mesma linha aparece
         duas vezes e outra "cai no vao" e nunca aparece;

      2. so paramos em pagina vazia: se a API tiver um limite interno
         menor que PAGE_LIMIT, receber menos linhas do que pedimos
         NAO significa que era a ultima pagina;

      3. o offset avanca pelo tamanho REAL do que chegou, nao pelo
         que foi pedido - assim nenhuma linha e pulada.
    """
    params = dict(params or {})
    params.setdefault("order", "id.asc")  # ordem estavel entre paginas
    offset = 0
    rows = []

    while True:
        params.update({"offset": offset,
                       "limit": PAGE_LIMIT})
        batch = get(endpoint, params)

        if not batch:  # pagina vazia = chegamos ao fim de verdade
            break

        rows.extend(batch)
        offset += len(batch)  # avanca pelo que realmente veio

    # Rede de seguranca: se mesmo assim vier duplicata, remove e AVISA
    # (aviso aqui e sinal de paginacao instavel do lado da API)
    if rows and "id" in rows[0]:
        unicos = {}
        for row in rows:
            unicos[row["id"]] = row
        if len(unicos) != len(rows):
            print(f"  aviso: {len(rows) - len(unicos)} linhas duplicadas "
                  f"removidas em {endpoint}")
        rows = list(unicos.values())

    return rows


def buscar_seasons(league_id):
    """
    O endpoint devolve um 'envelope' por liga, com a lista de seasons
    dentro. Aqui achatamos isso: uma linha por season, carimbada com
    o id e o nome da liga.
    """
    envelopes = get("seasons-by-league",
                    {"league_id": f"eq.{league_id}"})

    seasons = []
    for envelope in envelopes:
        for season in envelope.get("seasons", []):
            line = dict(season)
            line["league_id"] = envelope.get("league_id")
            line["league_name"] = envelope.get("league_name")
            seasons.append(line)

    return seasons


# ---------------------------------------------------------------------------
#                            READING AND SAVING FILES
# ---------------------------------------------------------------------------

def load(name):
    """Le um JSON do bronze/ se existir; senao, devolve lista vazia."""
    path = OUT_DIR / f"{name}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return []


def save(name, data):
    """Salva a lista como JSON legivel (indentado, com acentos)."""
    path = OUT_DIR / f"{name}.json"
    path.write_text(json.dumps(data,
                               ensure_ascii=False,
                               indent=2),
                    encoding="utf-8")


# ---------------------------------------------------------------------------
#                                  INGESTAO
# ---------------------------------------------------------------------------

def main():

    # 0) Seasons da liga - a dimensao que ancora tudo
    print("Buscando seasons...")
    seasons = buscar_seasons(LEAGUE_ID)
    save("seasons", seasons)

    if not seasons:
        raise ValueError(
            f"Nenhuma season encontrada para a liga {LEAGUE_ID}. "
            "Verifique o formato do envelope de liga."
        )

    if SEASON_IDS is None:
        alvos = [s["id"] for s in seasons]
    else:
        alvos = list(SEASON_IDS)

    print(f"{len(alvos)} seasons para ingerir:")
    for s in seasons:
        marca = " <--" if s["id"] in alvos else ""
        print(f"  {s['id']:>6}  {s.get('year', ''):<8} {s.get('name', '')}{marca}")

    # 1) Matches de todas as seasons alvo
    matches = []
    for season_id in alvos:
        print(f"Buscando matches da season {season_id}...")
        batch = paginate("matches",
                         {"season_id": f"eq.{season_id}"})

        # carimba a origem - o endpoint pode nao devolver season_id na linha
        for m in batch:
            m.setdefault("season_id", season_id)

        print(f"  {len(batch)} matches")
        matches.extend(batch)

    save("matches", matches)
    print(f"Total: {len(matches)} matches em {len(alvos)} seasons")

    # -----------------------------------------------------------------------
    # Cache entre execucoes - muitos matches repetem os mesmos times
    # -----------------------------------------------------------------------

    teams = load("teams")
    players_by_team = load("players_by_team")
    players = load("players")

    # Conjuntos (sets) com os ids que ja temos: consultar "x in set"
    # e instantaneo, entao o loop grande fica rapido.
    seen_teams = {t["id"] for t in teams}
    seen_players = {p["id"] for p in players}
    seen_links = {link["team_id"] for link in players_by_team}

    # matches-statistics: cache por status - jogo terminado nao muda mais
    stats_por_id = {s["match_id"]: s for s in load("matches_statistics")}

    # Contagem inicial - antes do loop, para o resumo final fazer sentido
    teams_before = len(seen_teams)
    players_before = len(seen_players)

    # O try/finally garante que, se algo quebrar no meio do loop
    # (queda de rede, API fora do ar), tudo que ja foi baixado e
    # salvo em disco mesmo assim. Na proxima execucao o cache
    # retoma de onde parou, sem repetir requisicao.
    try:
        for m in matches:
            match_id = m["id"]
            status = m.get("status_type")

            # 2) Estatisticas: SO de jogos terminados que ainda nao temos.
            #    - jogo nao comecou -> nao tem estatistica, seria
            #      requisicao jogada fora;
            #    - jogo ao vivo -> estatistica parcial, que congelaria
            #      no cache (o bug explicado la no docstring);
            #    - jogo terminado e ja no cache -> nao muda mais, pula.
            if status == "finished" and match_id not in stats_por_id:
                result = get("matches-statistics",
                             {"match_id": f"eq.{match_id}"})
                for s in result:
                    stats_por_id[s["match_id"]] = s

            # 3) Times (paises) do match.
            #    .get() em vez de [chave]: um match ainda sem adversario
            #    definido pode vir sem team_id (None), e ai so pulamos.
            for team_id in (m.get("home_team_id"), m.get("away_team_id")):
                if not team_id:
                    continue

                # 3a) detalhe do time - so se ainda nao temos
                if team_id not in seen_teams:
                    seen_teams.add(team_id)
                    print(f"  novo time {team_id}: buscando detalhe...")
                    teams.extend(get("teams",
                                     {"id": f"eq.{team_id}"}))

                # 4) elenco do time - checagem SEPARADA da de cima:
                #    se teams.json existe mas players_by_team.json foi
                #    apagado, ainda assim os elencos sao rebuscados.
                if team_id not in seen_links:
                    seen_links.add(team_id)
                    print(f"  time {team_id}: buscando elenco...")
                    team_rosters = get("players-by-team",
                                       {"team_id": f"eq.{team_id}"})
                    players_by_team.extend(team_rosters)

                    # 5) detalhe de cada jogadora nova
                    for roster in team_rosters:
                        for player in roster.get("players", []):
                            player_id = player["id"]

                            if player_id in seen_players:
                                continue
                            seen_players.add(player_id)

                            players.extend(get("players",
                                               {"id": f"eq.{player_id}"}))

    finally:
        # Salva tudo - roda tanto no fim normal quanto apos um erro
        save("matches_statistics", list(stats_por_id.values()))
        save("teams", teams)
        save("players_by_team", players_by_team)
        save("players", players)

    print(
        f"\nPronto. Base agora com: {len(matches)} matches, "
        f"{len(seen_teams)} teams, {len(seen_players)} players."
        f"\nNovos nesta execucao: {len(seen_teams) - teams_before} teams, "
        f"{len(seen_players) - players_before} players."
    )


if __name__ == "__main__":
    main()