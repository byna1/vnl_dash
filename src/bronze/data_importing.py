# %%
import pandas as pd
import requests as r
import json
from src.bronze.m_key import Key
import os

# 

headers =  {
        "x-rapidapi-key": Key

}
base = "https://volleyball.highlightly.net/"
path = "data/bronze/"


# 

def import_data(headers, base_url:str,endpoint:str, params=None):
        data = r.get(headers=headers,
                url=f"{base_url}{endpoint}", 
                params=params, 
                timeout=30)

        data = data.json()
        return data



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
                                         params= query)
                
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
                d = json.load(f)
        return d


# geting leagues
def getting_league(leagueName:str):
        leagues = import_paginated(headers,  base,"leagues", 
                                params={'leagueName': leagueName}
                                )
        saving_json(path,"leagues",leagues)
        # taking leagues id
        with open(f"{path}/leagues.json") as f: 
                dados = json.load(f)

        for i in dados:
                l_id = i["id"]
        print(l_id)

        return l_id



def import_base_for_league(l_id,l_file):
        # taking seasons ids
        with open(f"{path}/{l_file}.json") as f: 
                dados = json.load(f)

        season_ids = []

        for s in dados[0]["seasons"]:
                season_ids.append(s["season"])



        # geting matches
        matches = []

        for s_id in season_ids:
                getting_matches = import_paginated(headers=headers,
                                base_url=base,
                                endpoint="matches", params={"season"
                                                        : s_id, 
                                                        "leagueId": l_id})
                matches.extend(getting_matches)


        # 
        # separating teams ids



        teams_ids = set()

        for m in matches:
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




        # getting the mninimium date for the resarch of stats searchinig

        date = []

        for m in matches: 
        
               date.append(m["date"])

        base_start = min(date)[:10]

        team_stats = []

        # getting stats

        for tid in sorted(teams_ids):
                getting_stats = import_data(headers=headers,
                                base_url=base,
                                endpoint=f"teams/statistics/{tid}",
                                params={'fromDate':base_start}

                                )
                for s in getting_stats:
                        s["team_id"] = tid
                        team_stats.append(s)




        #  Voley Standings

        volley_standings = []

        for s_id in season_ids:
                getting_standings = import_data(headers=headers,
                                                base_url=base,
                                                endpoint="standings",
                                                params={
                                                        "leagueId":l_id,
                                                        "season":s_id})
                volley_standings.append(getting_standings)


        # Saving everything

        saving_json(path,"matches",matches)

        print("matches saved!")

        saving_json(path,"teams",teams)

        print("team saved!")

        saving_json(path,"team_stats",team_stats)

        print("team_stats saved!")
              
        saving_json(path,"standings",volley_standings)

        print("volley_standings saved!")


def main(): 
    
        league_id = getting_league("Nations League Women")
        import_base_for_league(league_id,"leagues")


if __name__ == "__main__":
        main()

        