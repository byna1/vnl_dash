# %%
# """
# Ingestao VNL feminina 2026 - Sportmicro API (bronze layer).

# Fluxo:
#     matches (temporada 103)
#       -> para cada match: matches-statistics
#       -> os times (paises) de cada match vem do proprio match -> teams
#       -> para cada time: players-by-team (a ponte time -> jogadora)
#       -> para cada jogadora: players (o detalhe da jogadora)

# Cache: times e jogadoras nao mudam de uma rodada para outra, entao
# antes de buscar o codigo le o que ja esta salvo em disco e so pede
# a API o que ainda falta. Assim voce nao gasta requisicao a toa.

# Cada endpoint e salvo em seu proprio arquivo JSON dentro de bronze/.
# """

import json
import time
from pathlib import Path

import requests
from Key import key

# ---------------------------------------------------------------------------
#                                   CONFIG
# ---------------------------------------------------------------------------

BASE_URL = "https://volleyball.sportmicro.com/"
HEADERS = {"Authorization": 
           f"Bearer {key}"}
SEASON_ID = 103 # This is the id for the 2026 season of VNL
PAGE_LIMIT = 50
SLEEP = 0.1  # The API has a bit of limitation, so I added a limit between the requisitions

OUT_DIR = Path("../data/bronze/")
OUT_DIR.mkdir(exist_ok=True)


# ---------------------------------------------------------------------------
#                                 REQUESTING
# ---------------------------------------------------------------------------

def get(endpoint, params=None): # This one makes simple requisitions (for the endpoints in which we do not neet pagination)
    
    resp = requests.get(f"{BASE_URL}{endpoint}",
                         headers=HEADERS, 
                         params=params)
    resp.raise_for_status()  # tells when error happened
    time.sleep(SLEEP)
    return resp.json()


def paginate(endpoint, params=None): # This one is for endpoints with longs responses that demand pagination
    
    params = dict(params or {})
    offset = 0
    rows = []
    while True:
        params.update({"offset": offset, 
                       "limit": PAGE_LIMIT})
        batch = get(endpoint, 
                    params)
        rows.extend(batch)
        if len(batch) < PAGE_LIMIT:
            break
        offset += PAGE_LIMIT
    return rows


# ---------------------------------------------------------------------------
#                            READING AND SAVING FILES
# ---------------------------------------------------------------------------

def load(name):
    path = OUT_DIR / f"{name}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return []

def save(name, data):
    path = OUT_DIR / f"{name}.json"
    path.write_text(json.dumps(data, 
                               ensure_ascii=False,
                               indent=2),
                    encoding="utf-8")


# ---------------------------------------------------------------------------
# Ingestao
# ---------------------------------------------------------------------------
def main():

    # 1) Matches of season -> big list into a page
    print("Searching matches...")
    matches = paginate("matches",
                       {"season_id": f"eq.{SEASON_ID}"})
    save("matches", matches)

    # Cache between executions - lots of matches have the same teams 
    
    teams = load("teams")
    players_by_team = load("players_by_team")
    players = load("players")

    seen_teams = {t["id"] 
                  for t in teams}
    seen_players = {p["id"] 
                    for p in players}
    seen_links = {link["team_id"]
                  for link in players_by_team}

    # matches-statistics: cache by status games finished does not change
    print("Checking if matches already exists...")
    stats_por_id = {s["match_id"]: s for s in load("matches_statistics")}



    for m in matches:
        match_id = m["id"]

        # 2) Just gets what has not been finished yet

        finalized_matches = m["status_type"] == "finished"
        matches_had = match_id in stats_por_id

        if not (finalized_matches and matches_had):
            result = get("matches-statistics", 
                         {"match_id": f"eq.{match_id}"})
            for s in result:
                stats_por_id[s["match_id"]] = s

        # 3) teams (countries) from match
        for team_id in (m["home_team_id"], m["away_team_id"]):
            if team_id in seen_teams:
                continue  # we already have this, skip it
            seen_teams.add(team_id)

            print("Searching statistics teams and players...")

            teams.extend(get("teams", {"id": f"eq.{team_id}"}))

            # 4) team -> players (only the ones we don't have yet)
            if team_id not in seen_links:
                seen_links.add(team_id)
                team_rosters = get("players-by-team", {"team_id": f"eq.{team_id}"})
                players_by_team.extend(team_rosters)

                # 5) detail of each player
                for roster in team_rosters:
                    for player in roster["players"]:
                        player_id = player["id"]

                        if player_id in seen_players:
                            continue
                        seen_players.add(player_id)

                        players.extend(get("players", {"id": f"eq.{player_id}"}))

    # Saves everything
    save("matches_statistics", list(stats_por_id.values()))
    save("teams", teams)
    save("players_by_team", players_by_team)    
    save("players", players)

    teams_before = len(seen_teams)
    players_before = len(seen_players)

    print(
        f"\nDone. Base now with: {len(matches)} matches, {len(seen_teams)} times, "
        f"\n{len(seen_players)} and players.",
        f"\nNew at this run: {len(seen_teams) - teams_before} times, ",
        f"\n{len(seen_players) - players_before} players."
    )


if __name__ == "__main__":
    main()
# %%
