# vnl_dash
this is a repo that contains all information about a vnl dashboard built with the intension of showcase the teams general metrics and their players specific metrics.

## VNL Data Portfolio

End-to-end data pipeline for Volleyball Nations League (VNL) statistics, built on a medallion architecture (bronze → silver → gold) and visualized in Power BI. Runs as a one-off, local, batch pipeline.

## Architecture

Web Scraping → Bronze (raw) → Silver (clean/normalized) → Gold (analytics) → Power BI


Bronze — raw scraped data, stored as-is with ingestion metadata. No cleaning.
Silver — cleaned, typed, deduplicated, normalized into dimension and fact tables.
Gold — aggregated tables modeled for consumption (star schema). Percentages computed here or as Power BI measures.
Power BI — connects to the gold layer to build metrics and dashboards.


## Pipeline Steps


- Web Scraping — collect VNL match and player statistics; persist raw output to the bronze layer.
- Silver Treatment — clean and type the data, standardize column names (no accents/spaces), deduplicate, and load into the normalized schema below.
- Gold Treatment — aggregate silver tables into consumption-ready tables (per player per game, per team, per tournament).
- Import to Power BI — connect Power BI to the gold layer.
- Create Metrics — build DAX measures (serve efficiency, reception positive %, break points, etc.).
- Create Visuals — design charts for player, team, and tournament analysis.
- Dashboard Design & Implementation — assemble and style the dashboard.
- Publish — export the dashboard and publish the repository (code, .pbix, screenshots).


## Data Model (Silver)

### Dimensions

- Dim_country

    ColumnTypeKeyCountryCodeintPKCountryNametext

- Dim_player

    ColumnTypeKeyPlayerCodeintPKPlayerNametextCountryCodeintFK → Dim_country

## Facts

- Fact_Game — grain: one match

    ColumnTypeKeycod_gameintPKcod_country_1intFK → Dim_countrycod_country_2intFK → Dim_countrycod_winnerintFK → Dim_country

- Fact_Set — grain: one set of a match

    ColumnTypeKeySet_IDintPKcod_gameintFK → Fact_Gameset_numberint (1–5)PointsCountry_1intPointsCountry_2intWinnerintFK → Dim_country

- Fact_Points — grain: player × set

    ColumnTypeKeyset_idintFK → Fact_SetplayerintFK → Dim_playerbpintvpinttotalint

- Fact_Serves — grain: player × set

    ColumnTypeKeyset_idintFK → Fact_SetplayerintFK → Dim_playerMistakesintRightsint

- Fact_Reception — grain: player × set

    ColumnTypeKeyset_idintFK → Fact_SetplayerintFK → Dim_playerTotalinterrorsint

## Notes


- Serve efficiency and reception positive % are derived metrics — computed in the gold layer or as Power BI measures, not stored in silver.

- Composite key on the fact stat tables: (set_id, player).

- Batch load, single run, no CDC — this is a static portfolio dataset.


## Tech Stack

Python (scraping) · SQL (transformations) · Power BI (visualization) · Git/GitHub

## Requirements

Numpy, pandas, requests

## Data

WebScrapped From: https://br.volleyballworld.com/