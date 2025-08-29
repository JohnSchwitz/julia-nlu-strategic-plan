# Julia NLU Strategic Plan Analysis

This project provides a stochastic modeling and analysis tool for a strategic business plan, focusing on the development and launch of several Natural Language Understanding (NLU) products. It forecasts project milestones and potential revenue streams based on configurable resource plans, task lists, and probabilistic market assumptions.

## Key Features

*   **Data-Driven:** Loads all core assumptions from easy-to-edit CSV files, including:
    *   Resource allocation (developers, marketers)
    *   Project task effort estimates
    *   Probabilistic parameters for revenue modeling
*   **Stochastic Forecasting:** Uses probability distributions to model revenue for multiple products (Nebula-NLU, Disclosure-NLU, Lingua-NLU), providing a more realistic range of potential outcomes.
*   **Milestone Calculation:** Dynamically calculates project milestone completion dates based on available work hours and task dependencies.
*   **Detailed Output:** Generates a comprehensive spreadsheet with the detailed plan, milestone dates, and revenue forecasts.
*   **Visualization:** Includes functions to generate plots for revenue distributions and variability over time.

## Project Structure

```
.
├── main.jl                   # Main module and entry point for the analysis
├── load_factors.jl           # Functions for loading and parsing CSV data
├── stochastic_model.jl       # Core logic for stochastic revenue modeling
├── presentation_output.jl    # Functions for generating spreadsheets and plots
├── *.csv                     # Data files (resource_plan, project_tasks, etc.)
├── Project.toml              # Julia project dependencies
└── Manifest.toml             # Exact versions of all dependencies
```

## Getting Started

### Prerequisites

*   [Julia](https://julialang.org/downloads/) (v1.6 or later)

### Installation & Setup

1.  **Clone the repository:**
    ```sh
    git clone <your-repository-url>
    cd julia-nlu-strategic-plan
    ```

2.  **Launch the Julia REPL:**
    ```sh
    julia
    ```

3.  **Activate the Project Environment:**
    Press `]` to enter the package manager mode, then activate the local environment.
    ```julia
    (@v1.11) pkg> activate .
    ```

4.  **Instantiate Dependencies:**
    This will download and install all the necessary packages defined in `Project.toml` and `Manifest.toml`.
    ```julia
    (julia-nlu-strategic-plan) pkg> instantiate
    ```

5.  **Exit Package Mode:**
    Press `Backspace` to return to the standard Julia REPL prompt.

## Usage

To run the full analysis, execute the following commands from within the Julia REPL:

```julia
# Include the main project module
include("main.jl")

# Run the analysis function
results = ProjectAnalysis.run_analysis();
```

This will perform all calculations and generate an output spreadsheet in the project's root directory. The `results` variable will contain a named tuple with all the calculated data for further interactive analysis if desired.

### Configuration

To change the simulation parameters, you can modify the data in the following files:
*   `config.csv`
*   `resource_plan.csv`
*   `project_tasks.csv`
*   `probability_parameters.csv`