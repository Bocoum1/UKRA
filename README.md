# UKRA - UK Road Accidents BI Dashboard

Interactive Business Intelligence dashboard built with **R Shiny** to analyze road accidents in the United Kingdom for **2021-2022**.

## Live Application

Explore the published dashboard: **[UKRA - Road Safety Dashboard](https://datascienceappli.shinyapps.io/Securite_routiere/)**

The project was developed in an academic BI setting and focuses on:
- global reporting on accidents and casualties;
- severity analysis across key risk factors;
- territorial analysis by district;
- temporal analysis by month, day, and hour.

## Overview

This dashboard helps explore road accident patterns and identify the conditions most associated with severe collisions. It combines a decision-oriented interface with descriptive BI indicators and interactive visualizations.

Main features:
- KPI cards for accidents, casualties, and severe/fatal accident rates;
- trend analysis over time;
- territorial view with district-level mapping;
- severity analysis by weather, light conditions, speed limit, road type, and area;
- temporal breakdowns by month, weekday, and hour.

## Project Structure

```text
.
├── app.R
├── README.md
├── Rapport_BI.pdf
└── screenshots/
```

## Run Locally

Make sure the required R packages are installed:

```r
install.packages(c(
  "shiny", "readxl", "dplyr", "ggplot2", "plotly",
  "leaflet", "DT", "lubridate", "scales"
))
```

Then launch the app from the project directory:

```bash
Rscript -e "shiny::runApp('.')"
```

## Dataset

The raw dataset is **not included** in this repository.

This project uses UK road safety open data published by the **Department for Transport**:
- Road Safety Data: https://www.data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-accidents-safety-data
- Road safety collection: https://www.data.gov.uk/collections/transport/road-safety

To run the dashboard locally, place the source Excel file in the repository root with the name:

```text
Road_Accident_Data.xlsx
```

## Report

The final BI report included in this repository is:
- `Rapport_BI.pdf`

## Screenshots

### Global Overview

![Global overview](screenshots/vue-globale.png)

### Territorial View

![Territorial view](screenshots/vue-territoriale.png)

### Risk Factors

![Risk factors](screenshots/facteurs-risque.png)

## Authors

- Amadou Bocoum
- Anya Leveque
