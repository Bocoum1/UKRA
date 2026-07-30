library(shiny)
library(readxl)
library(dplyr)
library(ggplot2)
library(plotly)
library(leaflet)
library(DT)
library(lubridate)
library(scales)

##########  PARAMETRES GENERAUX  ##########

# Fichiers utilises par le dashboard
data_file <- "Road_Accident_Data.xlsx"
cache_file <- "road_accident_data.rds"

severity_levels <- c("Fatal", "Serious", "Slight")
weekday_levels <- c(
  "Monday", "Tuesday", "Wednesday", "Thursday",
  "Friday", "Saturday", "Sunday"
)

fmt_int <- label_number(big.mark = " ", decimal.mark = ",")
fmt_pct <- label_percent(accuracy = 0.1, decimal.mark = ",")
severity_labels_fr <- c(
  "Fatal" = "Mortelle",
  "Serious" = "Grave",
  "Slight" = "Legère"
)

# Fonction utilitaire pour generer les cartes KPI
metric_card <- function(title, value, subtitle, accent) {
  div(
    class = "metric-card",
    style = paste0("--accent:", accent, ";"),
    div(class = "metric-title", title),
    div(class = "metric-value", value),
    div(class = "metric-subtitle", subtitle)
  )
}

##########  PREPARATION DES DONNEES  ##########

# Lecture, preparation et mise en cache des donnees
load_accident_data <- function(path_xlsx = data_file, path_cache = cache_file) {
  required_columns <- c(
    "accident_index",
    "accident_date",
    "year",
    "district",
    "road_type",
    "weather_conditions_reduced",
    "severity_fr",
    "hour",
    "is_serious_or_fatal"
  )

  if (!file.exists(path_xlsx)) {
    stop("Le fichier de données 'Road_Accident_Data.xlsx' est introuvable.")
  }

  # Recharge le cache si le fichier prepare est deja disponible
  if (file.exists(path_cache) && file.mtime(path_cache) >= file.mtime(path_xlsx)) {
    cached_data <- readRDS(path_cache)
    if (all(required_columns %in% names(cached_data))) {
      return(cached_data)
    }
  }

  raw_data <- read_excel(path_xlsx)

  # Selection et transformation des variables utiles au dashboard
  accident_data <- raw_data %>%
    transmute(
      accident_index = Accident_Index,
      accident_date = as.Date(`Accident Date`),
      month_label = as.character(Month),
      day_of_week = Day_of_Week,
      year = as.integer(Year),
      junction_control = Junction_Control,
      junction_detail = Junction_Detail,
      accident_severity = factor(
        Accident_Severity,
        levels = severity_levels,
        ordered = TRUE
      ),
      latitude = as.numeric(Latitude),
      longitude = as.numeric(Longitude),
      district = `Local_Authority_(District)`,
      police_force = Police_Force,
      vehicle_type = Vehicle_Type,
      road_type = Road_Type,
      road_surface_conditions = Road_Surface_Conditions,
      weather_conditions = Weather_Conditions,
      light_conditions = Light_Conditions,
      urban_rural_area = Urban_or_Rural_Area,
      carriageway_hazards = Carriageway_Hazards,
      speed_limit = as.integer(Speed_limit),
      number_of_casualties = as.numeric(Number_of_Casualties),
      number_of_vehicles = as.numeric(Number_of_Vehicles),
      accident_time = Time
    ) %>%
    mutate(
      district = if_else(is.na(district) | district == "", "Unknown", district),
      vehicle_type = if_else(
        is.na(vehicle_type) | vehicle_type == "",
        "Unknown",
        vehicle_type
      ),
      weather_conditions = if_else(
        is.na(weather_conditions) | weather_conditions == "",
        "Unknown",
        weather_conditions
      ),
      light_conditions = if_else(
        is.na(light_conditions) | light_conditions == "",
        "Unknown",
        light_conditions
      ),
      urban_rural_area = if_else(
        is.na(urban_rural_area) | urban_rural_area == "",
        "Unknown",
        urban_rural_area
      ),
      road_type = if_else(is.na(road_type) | road_type == "", "Unknown", road_type),
      road_surface_conditions = if_else(
        is.na(road_surface_conditions) | road_surface_conditions == "",
        "Unknown",
        road_surface_conditions
      ),
      junction_detail = if_else(
        is.na(junction_detail) | junction_detail == "",
        "Unknown",
        junction_detail
      ),
      month_num = month(accident_date),
      month_label = factor(month.abb[month_num], levels = month.abb, ordered = TRUE),
      day_of_week = factor(day_of_week, levels = weekday_levels, ordered = TRUE),
      hour = hour(accident_time),
      severity_fr = factor(
        recode(as.character(accident_severity), !!!severity_labels_fr),
        levels = c("Legere", "Grave", "Mortelle")
      ),
      weather_conditions_reduced = case_when(
        weather_conditions %in% c("Fine no high winds", "Fine + high winds") ~ "Fine",
        weather_conditions %in% c("Raining no high winds", "Raining + high winds") ~ "Pluie",
        weather_conditions %in% c("Snowing no high winds", "Snowing + high winds") ~ "Neige",
        weather_conditions == "Fog or mist" ~ "Brouillard",
        weather_conditions == "Unknown" ~ "Unknown",
        TRUE ~ "Autres"
      ),
      is_serious_or_fatal = accident_severity %in% c("Fatal", "Serious")
    ) %>%
    arrange(accident_date)

  # Sauvegarde un cache local pour accelerer les lancements suivants
  saveRDS(accident_data, path_cache)
  accident_data
}

accidents <- load_accident_data()

##########  INTERFACE UTILISATEUR  ##########

# Interface du tableau de bord
ui <- fluidPage(
  tags$head(
    tags$style(
      HTML(
        "
        body {
          background: linear-gradient(180deg, #f6f3eb 0%, #f7f7f9 100%);
          color: #172033;
        }
        .main-header {
          background: linear-gradient(135deg, #0b3c5d 0%, #1b6f8a 100%);
          color: white;
          border-radius: 18px;
          padding: 22px 26px;
          margin-bottom: 18px;
          box-shadow: 0 12px 30px rgba(11, 60, 93, 0.20);
        }
        .main-header-inner {
          display: flex;
          align-items: center;
          gap: 18px;
        }
        .main-header-copy {
          flex: 1;
          min-width: 0;
        }
        .main-logo {
          width: 74px;
          height: 74px;
          border-radius: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          background: linear-gradient(180deg, rgba(255, 255, 255, 0.22) 0%, rgba(255, 255, 255, 0.10) 100%);
          border: 1px solid rgba(255, 255, 255, 0.22);
          box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.18);
          font-size: 19px;
          font-weight: 800;
          letter-spacing: 0.16em;
          text-transform: uppercase;
        }
        .main-header h1 {
          margin: 0 0 8px 0;
          font-size: 28px;
          font-weight: 800;
        }
        .main-header p {
          margin: 0;
          font-size: 14px;
          opacity: 0.94;
        }
        .control-panel {
          background: linear-gradient(180deg, #e9f1f5 0%, #dbe8ef 100%);
          border: 1px solid rgba(11, 60, 93, 0.14);
          border-radius: 16px;
          padding: 18px 18px 10px 18px;
          box-shadow: 0 10px 24px rgba(23, 32, 51, 0.08);
        }
        .control-panel .form-group label,
        .control-panel p,
        .control-panel .checkbox label,
        .control-panel .radio label {
          color: #18364a;
          font-weight: 600;
        }
        .control-panel .irs--shiny .irs-bar,
        .control-panel .irs--shiny .irs-single,
        .control-panel .irs--shiny .irs-from,
        .control-panel .irs--shiny .irs-to {
          background: #1b6f8a;
          border-color: #1b6f8a;
        }
        .metric-card {
          background: white;
          border-radius: 16px;
          padding: 18px;
          margin-bottom: 16px;
          border-top: 5px solid var(--accent);
          box-shadow: 0 10px 24px rgba(23, 32, 51, 0.08);
          min-height: 132px;
        }
        .metric-title {
          font-size: 13px;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: #5c677d;
          margin-bottom: 12px;
          font-weight: 700;
        }
        .metric-value {
          font-size: 34px;
          line-height: 1.05;
          font-weight: 800;
          color: #0f172a;
          margin-bottom: 10px;
        }
        .metric-subtitle {
          font-size: 13px;
          color: #5c677d;
        }
        .section-note {
          background: rgba(255, 255, 255, 0.92);
          border-left: 4px solid #c26a3d;
          border-radius: 12px;
          padding: 12px 14px;
          margin-bottom: 16px;
          color: #364152;
        }
        .frame-card {
          background: white;
          border-radius: 16px;
          padding: 18px;
          margin-bottom: 16px;
          box-shadow: 0 10px 24px rgba(23, 32, 51, 0.08);
          border: 1px solid rgba(11, 60, 93, 0.08);
          min-height: 180px;
        }
        .frame-card h4 {
          margin-top: 0;
          margin-bottom: 10px;
          color: #0b3c5d;
          font-weight: 800;
        }
        .frame-card p {
          color: #435066;
          line-height: 1.55;
        }
        .nav-tabs {
          margin-top: 6px;
          border-bottom: none;
        }
        .nav-tabs > li > a {
          border-radius: 12px;
          color: #314158;
          font-weight: 600;
        }
        .nav-tabs > li.active > a,
        .nav-tabs > li.active > a:hover,
        .nav-tabs > li.active > a:focus {
          background: #0b3c5d;
          color: white;
          border: 1px solid #0b3c5d;
        }
        .tab-pane {
          background: rgba(255, 255, 255, 0.78);
          border-radius: 18px;
          padding: 18px;
          margin-top: 10px;
          box-shadow: 0 10px 24px rgba(23, 32, 51, 0.06);
        }
        "
      )
    )
  ),
  div(
    class = "main-header",
    div(
      class = "main-header-inner",
      div(class = "main-logo", "UKRA"),
      div(
        class = "main-header-copy",
        h1("UKRA - Projet BI sécurite routière"),
        p(
          "Analyse des accidents de la route au Royaume-Uni (2021-2022) ",
          "- Amadou Bocoum & Anya Levêque"
        )
      )
    )
  ),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      div(
        class = "control-panel",
        p(
          "Les filtres ci-dessous s'appliquent a l'ensemble du tableau de bord."
        ),
        selectInput(
          "year",
          "Année",
          choices = c("Toutes", sort(unique(accidents$year))),
          selected = "Toutes"
        ),
        selectizeInput(
          "districts",
          "District(s)",
          choices = sort(unique(accidents$district)),
          multiple = TRUE,
          options = list(
            placeholder = "Tous les districts"
          )
        ),
        selectizeInput(
          "vehicles",
          "Type(s) de véhicule",
          choices = sort(unique(accidents$vehicle_type)),
          multiple = TRUE,
          options = list(
            placeholder = "Tous les types de véhicule"
          )
        ),
        checkboxGroupInput(
          "severity",
          "Gravité",
          choices = severity_levels,
          selected = severity_levels
        ),
        checkboxGroupInput(
          "areas",
          "Zone",
          choices = sort(unique(accidents$urban_rural_area)),
          selected = sort(unique(accidents$urban_rural_area))
        ),
        sliderInput(
          "speed_range",
          "Limitation de vitesse",
          min = min(accidents$speed_limit, na.rm = TRUE),
          max = max(accidents$speed_limit, na.rm = TRUE),
          value = range(accidents$speed_limit, na.rm = TRUE),
          step = 10
        )
      )
    ),
    mainPanel(
      width = 9,
      div(
        class = "section-note",
        p(
          "Ce tableau de bord présente une analyse des accidents de la route au ",
          "Royaume-Uni sur les années 2021 et 2022. Il permet de visualiser ",
          "leur évolution, d'étudier leur gravité et d'identifier les ",
          "principaux facteurs associés aux situations les plus critiques. ",
          "L'objectif est de mieux comprendre dans quelles conditions les ",
          "accidents surviennent et deviennent les plus graves, afin d'aider ",
          "à l'identification des zones, des périodes et des profils de risque ",
          "prioritaires."
        )
      ),
      tabsetPanel(
        tabPanel(
          "Vue Globale",
          fluidRow(
            column(3, uiOutput("card_accidents")),
            column(3, uiOutput("card_casualties")),
            column(3, uiOutput("card_severity_rate")),
            column(3, uiOutput("card_avg_casualties"))
          ),
          fluidRow(
            column(8, plotlyOutput("monthly_trend", height = "320px")),
            column(4, plotlyOutput("severity_chart", height = "320px"))
          ),
          fluidRow(
            column(6, plotlyOutput("vehicle_chart", height = "320px")),
            column(6, plotlyOutput("area_chart", height = "320px"))
          ),
          fluidRow(
            column(12, DTOutput("monthly_table"))
          )
        ),
        tabPanel(
          "Vue transversale territoriale",
          fluidRow(
            column(7, leafletOutput("district_map", height = "560px")),
            column(5, plotlyOutput("top_districts", height = "280px"))
          ),
          fluidRow(
            column(12, DTOutput("district_table"))
          )
        ),
        tabPanel(
          "Facteurs de risque",
          fluidRow(
            column(6, plotlyOutput("weather_severity", height = "330px")),
            column(6, plotlyOutput("light_severity", height = "330px"))
          ),
          fluidRow(
            column(6, plotlyOutput("speed_severity", height = "330px")),
            column(6, plotlyOutput("road_type_chart", height = "330px"))
          )
        ),
        tabPanel(
          "Analyse temporelle",
          fluidRow(
            column(
              4,
              div(
                class = "frame-card",
                h4("Mesure temporelle"),
                selectInput(
                  "temporal_metric",
                  "Mesure",
                  choices = c(
                    "Nombre d'accidents" = "accidents",
                    "Nombre de victimes" = "victims"
                  ),
                  selected = "accidents"
                )
              )
            ),
            column(4, uiOutput("card_peak_period")),
            column(4, plotlyOutput("month_peak_chart", height = "180px"))
          ),
          fluidRow(
            column(7, plotlyOutput("weekday_chart", height = "320px")),
            column(5, plotlyOutput("hour_chart", height = "320px"))
          ),
          fluidRow(
            column(12, plotlyOutput("monthly_compare", height = "330px"))
          )
        )
      )
    )
  )
)

##########  LOGIQUE SERVEUR  ##########

# Reactions et visualisations du dashboard
server <- function(input, output, session) {
  
  ##########  DONNEES FILTREES  ##########
  
  # Filtre central applique a toutes les pages
  filtered_data <- reactive({
    data <- accidents

    if (!identical(input$year, "Toutes")) {
      data <- data %>% filter(year == as.integer(input$year))
    }

    if (length(input$districts) > 0) {
      data <- data %>% filter(district %in% input$districts)
    }

    if (length(input$vehicles) > 0) {
      data <- data %>% filter(vehicle_type %in% input$vehicles)
    }

    if (length(input$severity) == 0) {
      return(data[0, ])
    }

    if (length(input$areas) == 0) {
      return(data[0, ])
    }

    data %>%
      filter(
        as.character(accident_severity) %in% input$severity,
        urban_rural_area %in% input$areas,
        between(speed_limit, input$speed_range[1], input$speed_range[2])
      )
  })

  temporal_metric_fun <- reactive({
    if (identical(input$temporal_metric, "victims")) {
      function(data) sum(data$number_of_casualties, na.rm = TRUE)
    } else {
      function(data) nrow(data)
    }
  })

  aggregated_districts <- reactive({
    filtered_data() %>%
      group_by(district) %>%
      summarise(
        accidents = n(),
        casualties = sum(number_of_casualties, na.rm = TRUE),
        severe_rate = mean(is_serious_or_fatal, na.rm = TRUE),
        latitude = mean(latitude, na.rm = TRUE),
        longitude = mean(longitude, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      filter(is.finite(latitude), is.finite(longitude))
  })

  monthly_reporting <- reactive({
    filtered_data() %>%
      count(
        month_start = floor_date(accident_date, unit = "month"),
        severity_fr,
        .drop = FALSE
      ) %>%
      tidyr::pivot_wider(
        names_from = severity_fr,
        values_from = n,
        values_fill = 0
      ) %>%
      mutate(
        Total = Legere + Grave + Mortelle,
        Mois = format(month_start, "%b %Y")
      ) %>%
      arrange(month_start)
  })

  peak_period <- reactive({
    filtered_data() %>%
      filter(!is.na(day_of_week), !is.na(hour)) %>%
      count(day_of_week, hour, sort = TRUE) %>%
      slice_head(n = 1)
  })

  ##########  PAGE VUE GLOBALE  ##########
  
  # Cartes de synthese affichees en haut de la page
  output$card_accidents <- renderUI({
    data <- filtered_data()
    metric_card(
      "Accidents",
      fmt_int(nrow(data)),
      "Volume total d'accidents observés",
      "#0b3c5d"
    )
  })

  output$card_casualties <- renderUI({
    data <- filtered_data()
    metric_card(
      "Victimes",
      fmt_int(sum(data$number_of_casualties, na.rm = TRUE)),
      "Nombre total de victimes",
      "#c26a3d"
    )
  })

  output$card_severity_rate <- renderUI({
    data <- filtered_data()
    rate <- if (nrow(data) == 0) 0 else mean(data$is_serious_or_fatal, na.rm = TRUE)
    metric_card(
      "Taux grave/fatal",
      fmt_pct(rate),
      "Part des accidents graves ou fatals",
      "#8b1e3f"
    )
  })

  output$card_avg_casualties <- renderUI({
    data <- filtered_data()
    avg_value <- if (nrow(data) == 0) 0 else mean(data$number_of_casualties, na.rm = TRUE)
    metric_card(
      "Victimes / accident",
      number(avg_value, accuracy = 0.01, decimal.mark = ","),
      "Moyenne de victimes par accident",
      "#3b7d3a"
    )
  })

  # Tableau mensuel detaille par gravite
  output$monthly_table <- renderDT({
    data <- monthly_reporting()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    datatable(
      data %>%
        transmute(
          Mois,
          `Accidents legers` = Legere,
          `Accidents graves` = Grave,
          `Accidents mortels` = Mortelle,
          `Total accidents` = Total
        ),
      rownames = FALSE,
      options = list(pageLength = 8, dom = "tip", scrollX = TRUE)
    )
  })

  output$monthly_trend <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    plot_data <- data %>%
      count(month_start = floor_date(accident_date, unit = "month"))

    p <- ggplot(plot_data, aes(month_start, n, text = paste0(
      "Mois: ", format(month_start, "%Y-%m"),
      "<br>Accidents: ", fmt_int(n)
    ))) +
      geom_line(color = "#0b3c5d", linewidth = 1.1) +
      geom_point(color = "#c26a3d", size = 2.4) +
      labs(
        title = "Evolution mensuelle des accidents",
        x = NULL,
        y = "Nombre d'accidents"
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  output$severity_chart <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    plot_data <- data %>%
      count(accident_severity) %>%
      mutate(accident_severity = factor(accident_severity, levels = severity_levels))

    p <- ggplot(plot_data, aes(
      x = accident_severity,
      y = n,
      fill = accident_severity,
      text = paste0(
        "Gravité: ", accident_severity,
        "<br>Accidents: ", fmt_int(n)
      )
    )) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = c(
        "Fatal" = "#8b1e3f",
        "Serious" = "#c26a3d",
        "Slight" = "#5f8f3e"
      )) +
      labs(
        title = "Répartition par gravité",
        x = NULL,
        y = "Nombre d'accidents"
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  output$vehicle_chart <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    plot_data <- data %>%
      count(vehicle_type, sort = TRUE) %>%
      slice_head(n = 10) %>%
      mutate(vehicle_type = reorder(vehicle_type, n))

    p <- ggplot(plot_data, aes(
      x = vehicle_type,
      y = n,
      text = paste0(
        "Véhicule: ", vehicle_type,
        "<br>Accidents: ", fmt_int(n)
      )
    )) +
      geom_col(fill = "#1b6f8a") +
      coord_flip() +
      labs(
        x = NULL,
        y = "Nombre d'accidents"
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>%
      layout(
        title = list(
          text = "Top 10 des types de véhicules impliqués",
          x = 0.5,
          xanchor = "center"
        ),
        margin = list(t = 60, b = 50)
      ) %>%
      config(displayModeBar = FALSE)
  })

  output$area_chart <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    plot_data <- data %>%
      count(urban_rural_area, accident_severity) %>%
      mutate(
        urban_rural_area = factor(
          urban_rural_area,
          levels = c("Urban", "Rural", "Unknown")
        )
      )

    p <- ggplot(plot_data, aes(
      x = urban_rural_area,
      y = n,
      fill = accident_severity,
      text = paste0(
        "Zone: ", urban_rural_area,
        "<br>Gravité: ", accident_severity,
        "<br>Accidents: ", fmt_int(n)
      )
    )) +
      geom_col(position = "stack") +
      scale_fill_manual(values = c(
        "Fatal" = "#8b1e3f",
        "Serious" = "#c26a3d",
        "Slight" = "#5f8f3e"
      )) +
      labs(
        title = "Accidents par zone",
        x = NULL,
        y = "Nombre d'accidents",
        fill = "Gravité"
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  ##########  PAGE VUE TERRITORIALE  ##########
  
  # Carte des districts coloree selon le taux d'accidents graves ou fatals
  output$district_map <- renderLeaflet({
    data <- aggregated_districts()
    validate(need(nrow(data) > 0, "Aucune donnée géographique pour ces filtres."))

    pal <- colorNumeric(
      palette = c("#f0ead6", "#d18f5c", "#8b1e3f"),
      domain = data$severe_rate
    )

    leaflet(data) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = ~rescale(sqrt(accidents), to = c(6, 24)),
        fillColor = ~pal(severe_rate),
        fillOpacity = 0.78,
        stroke = FALSE,
        popup = ~paste0(
          "<strong>", district, "</strong><br>",
          "Accidents: ", fmt_int(accidents), "<br>",
          "Victimes: ", fmt_int(casualties), "<br>",
          "Taux grave/fatal: ", fmt_pct(severe_rate)
        )
      ) %>%
      addLegend(
        "bottomright",
        pal = pal,
        values = ~severe_rate,
        title = "Taux grave/fatal",
        opacity = 0.8
      )
  })

  output$top_districts <- renderPlotly({
    data <- aggregated_districts()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    plot_data <- data %>%
      arrange(desc(accidents)) %>%
      slice_head(n = 10) %>%
      mutate(district = reorder(district, accidents))

    p <- ggplot(plot_data, aes(
      x = district,
      y = accidents,
      text = paste0(
        "District: ", district,
        "<br>Accidents: ", fmt_int(accidents),
        "<br>Victimes: ", fmt_int(casualties)
      )
    )) +
      geom_col(fill = "#c26a3d") +
      coord_flip() +
      labs(
        x = NULL,
        y = "Nombre d'accidents"
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% layout(
      title = list(
        text = "Top 10 des districts les plus accidentogènes",
        x = 0.5,
        xanchor = "center",
        font = list(size = 19)
      ),
      margin = list(t = 60, b = 50)
    ) %>% config(displayModeBar = FALSE)
  })

  output$district_table <- renderDT({
    data <- aggregated_districts()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    table_data <- data %>%
      arrange(desc(accidents)) %>%
      transmute(
        District = district,
        Accidents = fmt_int(accidents),
        Victimes = fmt_int(casualties),
        `Taux grave/fatal` = fmt_pct(severe_rate)
      )

    datatable(
      table_data,
      rownames = FALSE,
      options = list(pageLength = 10, dom = "tip")
    )
  })

  ##########  PAGE FACTEURS DE RISQUE  ##########
  
  # Analyse de la gravite selon la meteo regroupee
  output$weather_severity <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    top_weather <- data %>%
      count(weather_conditions_reduced, sort = TRUE) %>%
      slice_head(n = 6)

    plot_data <- data %>%
      filter(weather_conditions_reduced %in% top_weather$weather_conditions_reduced) %>%
      count(weather_conditions_reduced, accident_severity) %>%
      group_by(weather_conditions_reduced) %>%
      mutate(share = n / sum(n)) %>%
      ungroup() %>%
      mutate(weather_conditions_reduced = reorder(weather_conditions_reduced, share))

    p <- ggplot(plot_data, aes(
      x = weather_conditions_reduced,
      y = share,
      fill = accident_severity,
      text = paste0(
        "Meteo: ", weather_conditions_reduced,
        "<br>Gravité: ", accident_severity,
        "<br>Part: ", fmt_pct(share)
      )
    )) +
      geom_col(position = "fill") +
      coord_flip() +
      scale_fill_manual(values = c(
        "Fatal" = "#8b1e3f",
        "Serious" = "#c26a3d",
        "Slight" = "#5f8f3e"
      )) +
      scale_y_continuous(labels = fmt_pct) +
      labs(
        title = "Répartition de la gravité selon la météo",
        x = NULL,
        y = "Part des accidents",
        fill = "Gravité"
      ) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  output$light_severity <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    plot_data <- data %>%
      count(light_conditions, accident_severity) %>%
      group_by(light_conditions) %>%
      mutate(share = n / sum(n)) %>%
      ungroup() %>%
      mutate(light_conditions = reorder(light_conditions, share))

    p <- ggplot(plot_data, aes(
      x = light_conditions,
      y = share,
      fill = accident_severity,
      text = paste0(
        "Luminosite: ", light_conditions,
        "<br>Gravité: ", accident_severity,
        "<br>Part: ", fmt_pct(share)
      )
    )) +
      geom_col(position = "fill") +
      coord_flip() +
      scale_fill_manual(values = c(
        "Fatal" = "#8b1e3f",
        "Serious" = "#c26a3d",
        "Slight" = "#5f8f3e"
      )) +
      scale_y_continuous(labels = fmt_pct) +
      labs(
        x = NULL,
        y = "Part des accidents",
        fill = "Gravité"
      ) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% layout(
      title = list(
        text = "Répartition de la gravité selon la luminosité",
        x = 0.5,
        xanchor = "center",
        font = list(size = 19)
      ),
      margin = list(t = 60, b = 50)
    ) %>% config(displayModeBar = FALSE)
  })

  output$speed_severity <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnée pour ces filtres."))

    plot_data <- data %>%
      count(speed_limit, accident_severity) %>%
      mutate(speed_limit = factor(speed_limit, levels = sort(unique(speed_limit))))

    p <- ggplot(plot_data, aes(
      x = speed_limit,
      y = n,
      fill = accident_severity,
      text = paste0(
        "Vitesse: ", speed_limit, " mph",
        "<br>Gravité: ", accident_severity,
        "<br>Accidents: ", fmt_int(n)
      )
    )) +
      geom_col(position = "stack") +
      scale_fill_manual(values = c(
        "Fatal" = "#8b1e3f",
        "Serious" = "#c26a3d",
        "Slight" = "#5f8f3e"
      )) +
      labs(
        title = "Accidents par limitation de vitesse",
        x = "Limitation de vitesse (mph)",
        y = "Nombre d'accidents",
        fill = "Gravité"
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  output$road_type_chart <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnee pour ces filtres."))

    plot_data <- data %>%
      count(road_type, sort = TRUE) %>%
      slice_head(n = 8) %>%
      mutate(road_type = reorder(road_type, n))

    p <- ggplot(plot_data, aes(
      x = road_type,
      y = n,
      text = paste0(
        "Type de route: ", road_type,
        "<br>Accidents: ", fmt_int(n)
      )
    )) +
      geom_col(fill = "#0b3c5d") +
      coord_flip() +
      labs(
        title = "Types de route les plus impliqués",
        x = NULL,
        y = "Nombre d'accidents"
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  ##########  PAGE ANALYSE TEMPORELLE  ##########
  
  # Repartition de la mesure choisie selon les jours de la semaine
  output$weekday_chart <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnee pour ces filtres."))

    plot_data <- data %>%
      filter(!is.na(day_of_week)) %>%
      group_by(day_of_week) %>%
      summarise(value = temporal_metric_fun()(cur_data()), .groups = "drop")

    p <- ggplot(plot_data, aes(
      x = day_of_week,
      y = value,
      text = paste0(
        "Jour: ", day_of_week,
        if (identical(input$temporal_metric, "victims")) {
          paste0("<br>Victimes: ", fmt_int(value))
        } else {
          paste0("<br>Accidents: ", fmt_int(value))
        }
      )
    )) +
      geom_col(fill = "#1b6f8a") +
      labs(
        title = if (identical(input$temporal_metric, "victims")) {
          "Victimes par jour de la semaine"
        } else {
          "Accidents par jour de la semaine"
        },
        x = NULL,
        y = NULL
      ) +
      scale_y_continuous(labels = fmt_int) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  output$hour_chart <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnee pour ces filtres."))

    plot_data <- data %>%
      filter(!is.na(hour)) %>%
      group_by(hour) %>%
      summarise(value = temporal_metric_fun()(cur_data()), .groups = "drop")

    p <- ggplot(plot_data, aes(
      x = hour,
      y = value,
      text = paste0(
        "Heure: ", sprintf("%02d:00", hour),
        if (identical(input$temporal_metric, "victims")) {
          paste0("<br>Victimes: ", fmt_int(value))
        } else {
          paste0("<br>Accidents: ", fmt_int(value))
        }
      )
    )) +
      geom_line(color = "#c26a3d", linewidth = 1.2) +
      geom_point(color = "#0b3c5d", size = 2.2) +
      scale_x_continuous(breaks = seq(0, 23, by = 2)) +
      scale_y_continuous(labels = fmt_int) +
      labs(
        title = if (identical(input$temporal_metric, "victims")) {
          "Profil horaire des victimes"
        } else {
          "Profil horaire des accidents"
        },
        x = "Heure",
        y = NULL
      ) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  # Carte KPI indiquant le creneau le plus accidentogene
  output$card_peak_period <- renderUI({
    data <- peak_period()
    label <- if (nrow(data) == 0) {
      "Aucune donnee"
    } else {
      paste0(as.character(data$day_of_week[[1]]), " - ", sprintf("%02d:00", data$hour[[1]]))
    }

    metric_card(
      "Creneau le plus accidentogene",
      label,
      "Combinaison jour/heure la plus frequente dans la selection",
      "#8b1e3f"
    )
  })

  output$month_peak_chart <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnee pour ces filtres."))

    plot_data <- data %>%
      group_by(month_label) %>%
      summarise(value = temporal_metric_fun()(cur_data()), .groups = "drop")

    p <- ggplot(plot_data, aes(
      x = month_label,
      y = value,
      text = paste0(
        "Mois: ", month_label,
        if (identical(input$temporal_metric, "victims")) {
          paste0("<br>Victimes: ", fmt_int(value))
        } else {
          paste0("<br>Accidents: ", fmt_int(value))
        }
      )
    )) +
      geom_col(fill = "#c26a3d") +
      scale_y_continuous(labels = fmt_int) +
      labs(
        title = if (identical(input$temporal_metric, "victims")) {
          "Victimes par mois"
        } else {
          "Accidents par mois"
        },
        x = NULL,
        y = NULL
      ) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })

  output$monthly_compare <- renderPlotly({
    data <- filtered_data()
    validate(need(nrow(data) > 0, "Aucune donnee pour ces filtres."))

    plot_data <- data %>%
      count(year, month_label)

    p <- ggplot(plot_data, aes(
      x = month_label,
      y = n,
      fill = factor(year),
      text = paste0(
        "Annee: ", year,
        "<br>Mois: ", month_label,
        "<br>Accidents: ", fmt_int(n)
      )
    )) +
      geom_col(position = "dodge") +
      scale_y_continuous(labels = fmt_int) +
      scale_fill_manual(values = c("2021" = "#0b3c5d", "2022" = "#c26a3d")) +
      labs(
        title = "Comparaison mensuelle entre 2021 et 2022",
        x = NULL,
        y = "Nombre d'accidents",
        fill = "Annee"
      ) +
      theme_minimal(base_size = 12)

    ggplotly(p, tooltip = "text") %>% config(displayModeBar = FALSE)
  })
}

app <- shinyApp(ui = ui, server = server)
