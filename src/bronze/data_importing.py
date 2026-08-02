# %%
import pandas as pd
import requests as r
import json
from src.bronze.m_key import Key
import os
import requests_cache


# %%

headers =  {
        "x-rapidapi-key": Key

}

base = "https://volleyball.highlightly.net/"

path = "data/bronze/"
requests_cache.install_cache(f"{path}http_cache", expire_after=-1)


# %%

def import_data(headers, base_url:str,endpoint:str, params=None):
        data = r.get(headers=headers,
                url=f"{base_url}{endpoint}",
                params=params,
                timeout=30)
        if data.status_code == 429:
                raise SystemExit("API limit reached! Stopping...")
        data.raise_for_status()
        return data.json()


def import_paginated(headers,base_url:str,endpoint:str,params=None):
        data = []
        offset = 0
        limit = 100
        while True:

                query = dict(params or {})
                query.update({"offset":offset,
                        "limit":limit})

                full_data = import_data(headers,
                        base_url,endpoint,
                        params=query)

                batch = full_data.get("data",[])

                if not batch:
                        break

                data.extend(batch)

                offset = len(data)
        return data


def saving_json(file_path,file_name:str,data_to_save):
        path = f"{file_path}{file_name}.json"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
                json.dump(data_to_save,f,
                        ensure_ascii=False,
                        indent=2)


def load_json(path:str,file_name:str):
        with open(f"{path}/{file_name}.json") as f:
                return json.load(f)


def saved_seasons_for_league(file_name:str,l_id):
        # seasons already on disk for this league (empty if file not there yet)
        file = f"{path}{file_name}.json"
        if not os.path.exists(file):
                return set()
        with open(file, encoding='utf-8') as f:
                data = json.load(f)
        return {d["season"] for d in data if d.get("leagueId") == l_id}


def upsert_json(file_path,file_name:str,new_data,keys):
        path = f"{file_path}{file_name}.json"

        if os.path.exists(path):
                with open(path, encoding='utf-8') as f:
                        old_data = json.load(f)

        else:
                old_data = []

        def make_key(item):
                return tuple(item[k] for k in keys)

        indexed = {}

        for item in old_data:
                indexed[make_key(item)] = item

        for item in new_data:
                indexed[make_key(item)] = item

        saving_json(file_path,file_name,list(indexed.values()))


# getting leagues

def getting_league(leagueName:str):
        leagues = import_paginated(headers,  base,"leagues",
                                params={'leagueName': leagueName}
                                )
        if not leagues:
                raise ValueError(f"No league registered in {leagueName} name!")

        l_id = leagues[0]["id"]
        print(f"League id:{l_id}")
        return l_id

def getting_countries():
        countries = import_data(headers=headers,
                                base_url=base,
                                endpoint="countries")
        upsert_json(path,"countries",countries,["code"])
        print("countries saved!")
        return countries

def leagues_already_saved():
    # ids de liga que já têm matches salvos em disco
    file = f"{path}matches.json"
    if not os.path.exists(file):
        return set()
    with open(file, encoding='utf-8') as f:
        data = json.load(f)
    return {d["leagueId"] for d in data if "leagueId" in d}

# IMPORTING PIPELINE

def import_base_for_league(l_id,l_file):

        with open(f"{path}/{l_file}.json") as f:
                dados = json.load(f)

        league = None

        for lg in dados:
                if lg["id"] == l_id:
                        league = lg
                        break

        if league is None:
                print(f"league {l_id} not found, skipping")
                return

        season_ids = []
        for s in league["seasons"]:
                season_ids.append(s["season"])

        # latest season is the "current" one: always refetched, older seasons skipped if already saved

        current_season = max(season_ids)
        matches_done = saved_seasons_for_league("matches",l_id)
        standings_done = saved_seasons_for_league("standings",l_id)

        # getting matches
        
        matches = []

        for s_id in season_ids:
                if s_id != current_season and s_id in matches_done:
                        print(f"matches {l_id}/{s_id} already saved, skipping")
                        continue
                getting_matches = import_paginated(headers=headers,
                                base_url=base,
                                endpoint="matches", params={"season"
                                                        : s_id,
                                                        "leagueId": l_id})
                for m in getting_matches:
                        m["leagueId"] = l_id
                        m["season"] = s_id
                matches.extend(getting_matches)

        if not matches:
                print(f"no new matches for league {l_id}, skipping...")
                return

        # separating teams ids
        teams_ids = set()
        for m in matches:
                if not m.get("homeTeam") or not m.get("awayTeam"):
                        continue
                teams_ids.add(m["homeTeam"]["id"])
                teams_ids.add(m["awayTeam"]["id"])

        # getting teams
        teams = []
        for tid in sorted(teams_ids):
                print(f"Searching team {tid}...")
                getting_teams = import_data(headers=headers,
                                        base_url=base,
                                        endpoint=f"teams/{tid}")
                teams.extend(getting_teams)

        # minimum date for the stats search
        date = []
        for m in matches:
                date.append(m["date"])
        base_start = min(date)[:10]

        # getting stats
        team_stats = []
        for tid in sorted(teams_ids):
                getting_stats = import_data(headers=headers,
                                base_url=base,
                                endpoint=f"teams/statistics/{tid}",
                                params={'fromDate':base_start}
                                )
                for s in getting_stats:
                        if s["leagueId"] != l_id:
                                continue
                        s["team_id"] = tid
                        team_stats.append(s)

        # Volley Standings
        volley_standings = []
        for s_id in season_ids:
                if s_id != current_season and s_id in standings_done:
                        print(f"standings {l_id}/{s_id} already saved, skipping")
                        continue
                getting_standings = import_data(headers=headers,
                                                base_url=base,
                                                endpoint="standings",
                                                params={
                                                        "leagueId":l_id,
                                                        "season":s_id})
                volley_standings.append({"leagueId":l_id,
                                        "season":s_id,
                                        "data":getting_standings})

        # Saving everything
        upsert_json(path,"matches",matches,["id"])
        print("matches saved!")

        upsert_json(path,"teams",teams,["id"])
        print("teams saved!")

        upsert_json(path,"team_stats",team_stats,["team_id","leagueId","season"])
        print("team_stats saved!")

        upsert_json(path,"standings",volley_standings,["leagueId","season"])
        print("standings saved!")


# %%

# %%
def main():
    leagues = import_paginated(headers=headers,
                               base_url=base,
                               endpoint="leagues")
    saving_json(path, "leagues", leagues)

    l_ids = [l["id"] for l in leagues]

    have = leagues_already_saved()
    todo = [l_id for l_id in l_ids if l_id not in have]

    print(f"{len(todo)} ligas novas de {len(l_ids)} totais")

    for l_id in todo:
        import_base_for_league(l_id, "leagues")

    getting_countries()



# %%
if __name__ == "__main__":
        main()