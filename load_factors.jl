# load_factors.jl (corrected)
module LoadFactors

using DataFrames, CSV
export ResourcePlan, ProjectTask, Milestone, MonthlyForecast, DisclosureForecast, LinguaForecast
export load_configuration, load_resource_plan, load_tasks, load_probability_parameters

# ========== DATA STRUCTURES ==========
struct ResourcePlan
    work_days::Vector{Int}
    experienced_devs::Vector{Float64}
    intern_devs::Vector{Float64}
    experienced_marketers::Vector{Float64}
    intern_marketers::Vector{Float64}
    dev_efficiency::Vector{Float64}
    marketing_efficiency::Vector{Float64}
    months::Vector{String}
    dev_productivity_factor::Float64
    marketing_productivity_factor::Float64
    intern_productivity_factor::Float64
    # New compound growth factors
    nebula_12m_growth::Float64
    nebula_24m_growth::Float64
    disclosure_12m_growth::Float64
    disclosure_24m_growth::Float64
    lingua_12m_growth::Float64
    lingua_24m_growth::Float64
end

struct ProjectTask
    name::String
    planned_hours::Int
    sequence::Int
    task_type::String
end

struct Milestone
    task::String
    sequence::Int
    planned_hours::Int
    cumulative_hours::Int
    milestone_date::String
    available_hours::Float64
    buffer_hours::Float64
    resource_type::String
end

struct MonthlyForecast
    month::String
    new_customers::Int
    avg_purchases_per_customer::Float64
    annual_churn_rate::Float64
    total_customers::Int
    revenue_k::Float64 # Revenue in thousands
end

struct DisclosureForecast
    month::String
    new_clients::Int
    total_clients::Int
    total_solo::Int
    total_small::Int
    total_medium::Int
    total_large::Int
    total_biglaw::Int
    revenue_k::Float64
end

struct LinguaForecast
    month::String
    active_pairs::Int
    revenue_k::Float64
end

# ========== CONFIGURATION & DATA LOADING ==========
function load_configuration(filepath::String)
    config_df = CSV.read(filepath, DataFrame)
    config_dict = Dict(row.key => parse(Float64, string(row.value)) for row in eachrow(config_df))
    return config_dict
end

function load_resource_plan(filepath::String, config::Dict)
    df = CSV.read(filepath, DataFrame)

    # Handle the typo in the key name - check for both correct and typo versions
    lingua_24m_growth = if haskey(config, "Lingua_24M_Compound_Growth")
        config["Lingua_24M_Compound_Growth"]
    elseif haskey(config, "Lingua_24M_Compoun_Growth")
        config["Lingua_24M_Compoun_Growth"]
    else
        2.0  # Default value
    end

    return ResourcePlan(
        df.work_days,
        df.experienced_devs,
        df.intern_devs,
        df.experienced_marketers,
        df.intern_marketers,
        df.dev_efficiency,
        df.marketing_efficiency,
        df.month,
        config["dev_productivity_factor"],
        config["marketing_productivity_factor"],
        config["intern_productivity_factor"],
        config["Nebula_12M_Compound_Growth"],
        config["Nebula_24M_Compound_Growth"],
        config["Disclosure_12M_Compound_Growth"],
        config["Disclosure_24M_Compound_Growth"],
        config["Lingua_12M_Compound_Growth"],
        lingua_24m_growth
    )
end

function load_tasks(filepath::String)
    df = CSV.read(filepath, DataFrame)
    return [ProjectTask(row.name, row.planned_hours, row.sequence, row.task_type) for row in eachrow(df)]
end

function load_probability_parameters(filepath::String)
    df = CSV.read(filepath, DataFrame)
    params = Dict{String,Dict{String,Float64}}()
    for row in eachrow(df)
        platform = row.Platform
        if !haskey(params, platform)
            params[platform] = Dict{String,Float64}()
        end
        params[platform][row.Parameter_Name] = parse(Float64, string(row.Parameter_Value))
    end
    return params
end

end # module LoadFactors