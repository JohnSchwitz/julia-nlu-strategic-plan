module ProjectAnalysis

using DataFrames, Dates, StatsPlots, PrettyTables, CSV, Distributions

export run_analysis

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


# ========== CONFIGURATION & DATA LOADING ==========
function load_configuration(filepath::String)
    config_df = CSV.read(filepath, DataFrame)
    # Parse values to Float64 during dictionary creation for type stability
    config_dict = Dict(row.key => parse(Float64, string(row.value)) for row in eachrow(config_df))
    return config_dict
end

function load_resource_plan(filepath::String, config::Dict)
    df = CSV.read(filepath, DataFrame)

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
        config["intern_productivity_factor"]
    )
end

function load_tasks(filepath::String)
    df = CSV.read(filepath, DataFrame)
    # Use a comprehension for a more concise way to construct the task list
    return [ProjectTask(row.name, row.planned_hours, row.sequence, row.task_type) for row in eachrow(df)]
end

# ========== CALCULATION FUNCTIONS ==========
# Calculate monthly and cumulative resource hours
function calculate_resource_hours(plan::ResourcePlan)
    # Calculate monthly hours using broadcasting for a more concise and efficient calculation
    monthly_dev_hours = (plan.experienced_devs .* plan.dev_productivity_factor .+
                         plan.intern_devs .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.dev_efficiency

    monthly_marketing_hours = (plan.experienced_marketers .* plan.marketing_productivity_factor .+
                               plan.intern_marketers .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.marketing_efficiency

    # Calculate cumulative totals
    cumulative_dev_hours = cumsum(monthly_dev_hours)
    cumulative_marketing_hours = cumsum(monthly_marketing_hours)

    return (monthly_dev=monthly_dev_hours,
        monthly_marketing=monthly_marketing_hours,
        cumulative_dev=cumulative_dev_hours,
        cumulative_marketing=cumulative_marketing_hours)
end

# Calculate milestone completion dates based on available hours
function calculate_milestones(tasks::Vector{ProjectTask}, hours, months::Vector{String})
    dev_tasks = filter(t -> t.task_type == "Development", tasks)
    marketing_tasks = filter(t -> t.task_type == "Marketing", tasks)

    # Sort tasks by sequence within each type
    dev_tasks = sort(dev_tasks, by=t -> t.sequence)
    marketing_tasks = sort(marketing_tasks, by=t -> t.sequence)

    milestones = Milestone[]

    # Helper function to avoid code duplication
    function _calculate_milestones_for_type(task_list, cumulative_hours, resource_type, months)
        task_cumulative = 0
        for task in task_list
            task_cumulative += task.planned_hours
            milestone_month_idx = findfirst(h -> h >= task_cumulative, cumulative_hours)

            if milestone_month_idx !== nothing
                push!(milestones, Milestone(
                    task.name,
                    task.sequence,
                    task.planned_hours,
                    task_cumulative,
                    months[milestone_month_idx],
                    cumulative_hours[milestone_month_idx],
                    cumulative_hours[milestone_month_idx] - task_cumulative,
                    resource_type
                ))
            else
                push!(milestones, Milestone(
                    task.name,
                    task.sequence,
                    task.planned_hours,
                    task_cumulative,
                    "Beyond Plan",
                    0.0,
                    0.0,
                    resource_type
                ))
            end
        end
    end

    _calculate_milestones_for_type(dev_tasks, hours.cumulative_dev, "Development", months)
    _calculate_milestones_for_type(marketing_tasks, hours.cumulative_marketing, "Marketing", months)

    return milestones
end

# This new function encapsulates all business logic for task adjustments
function prepare_tasks(initial_tasks::Vector{ProjectTask}, hours)
    tasks = deepcopy(initial_tasks) # Use a copy to avoid modifying the original loaded tasks

    # Business Logic 2: Dynamically create "catch-all" tasks to consume remaining buffer hours
    dev_planned_total = sum(t.planned_hours for t in tasks if t.task_type == "Development")
    mktg_planned_total = sum(t.planned_hours for t in tasks if t.task_type == "Marketing")

    remaining_dev_hours = hours.cumulative_dev[end] - dev_planned_total
    remaining_mktg_hours = hours.cumulative_marketing[end] - mktg_planned_total

    # Dynamically find the next available sequence number for each track to make the model robust
    dev_sequences = [t.sequence for t in tasks if t.task_type == "Development"]
    mktg_sequences = [t.sequence for t in tasks if t.task_type == "Marketing"]

    next_dev_seq = isempty(dev_sequences) ? 1 : maximum(dev_sequences) + 1
    next_mktg_seq = isempty(mktg_sequences) ? 1 : maximum(mktg_sequences) + 1

    # Add the new tasks to the list. These will consume the buffer.
    push!(tasks, ProjectTask("Future Project Development", max(0, round(Int, remaining_dev_hours)), next_dev_seq, "Development"))
    push!(tasks, ProjectTask("Executing Mktg", max(0, round(Int, remaining_mktg_hours)), next_mktg_seq, "Marketing"))

    return tasks
end


# ========== FINANCIAL MODELING ==========
function model_nebula_revenue(plan::ResourcePlan)
    # --- Nebula-NLU B2B2C Model Parameters ---
    initial_customers = 200.0    # Starting customers in the first month of sales
    purchase_price = 10.0        # Average revenue per purchasing customer per month
    annual_growth_target = 1.5   # Target 150% growth
    sales_start_month = "Oct 2025"

    # --- Distribution Definitions ---
    # Mean purchases/customer/month is 1.0. Gamma captures variability.
    purchase_frequency_dist = Gamma(4, 0.25) # Shape and scale chosen to have a mean of 1.0
    # Mean annual churn of 20%
    churn_dist = Beta(1, 4)

    # --- Calculations ---
    g = (1 + annual_growth_target)^(1 / 12) - 1
    sales_started = false
    lambda = 0.0

    forecasts = MonthlyForecast[]
    total_customers = 0

    for (i, month_name) in enumerate(plan.months)
        if month_name == sales_start_month
            sales_started = true
            lambda = initial_customers
        elseif sales_started
            lambda *= (1 + g)
        end

        new_customers = sales_started ? rand(Poisson(lambda)) : 0
        avg_purchases_per_customer = rand(purchase_frequency_dist)
        annual_churn_rate = rand(churn_dist)

        monthly_churn_rate = 1 - (1 - annual_churn_rate)^(1 / 12)
        customers_retained = round(Int, total_customers * (1 - monthly_churn_rate))
        total_customers = customers_retained + new_customers

        monthly_revenue = total_customers * avg_purchases_per_customer * purchase_price

        push!(forecasts, MonthlyForecast(
            month_name, new_customers, avg_purchases_per_customer, annual_churn_rate,
            total_customers, monthly_revenue / 1000
        ))
    end

    return forecasts
end

function model_disclosure_revenue(plan::ResourcePlan, milestones::Vector{Milestone})
    # --- Disclosure-NLU B2B Model Parameters ---
    monthly_price_per_client = 2000.0 # High-value legal tech product
    clients_per_month_growth = 1.2    # 20% month-over-month growth in new client acquisition

    # Find when sales can start (2 months after MVP)
    # With the detailed task list, the MVP is considered complete after the last core UI feature is done.
    mvp_completion_task_name = "Disclosure - Mobile UI"
    mvp_milestone_idx = findfirst(m -> m.task == mvp_completion_task_name, milestones)
    mvp_completion_date = mvp_milestone_idx !== nothing ? milestones[mvp_milestone_idx].milestone_date : "Beyond Plan"

    sales_start_idx = findfirst(m -> m == mvp_completion_date, plan.months)
    sales_start_idx = sales_start_idx !== nothing ? sales_start_idx + 2 : length(plan.months) + 1

    forecasts = MonthlyForecast[]
    total_customers = 0
    new_customer_rate = 1.0

    for (i, month_name) in enumerate(plan.months)
        new_customers = 0
        if i >= sales_start_idx
            new_customers = round(Int, new_customer_rate)
            new_customer_rate *= clients_per_month_growth
        end

        # B2B churn is very low for high-value integrated products
        annual_churn_rate = rand(Beta(1, 15)) # ~6% annual churn
        monthly_churn_rate = 1 - (1 - annual_churn_rate)^(1 / 12)
        customers_retained = round(Int, total_customers * (1 - monthly_churn_rate))
        total_customers = customers_retained + new_customers

        # For this B2B model, purchase frequency is 1 (they pay their monthly subscription)
        avg_purchases_per_customer = 1.0
        monthly_revenue = total_customers * monthly_price_per_client

        push!(forecasts, MonthlyForecast(
            month_name, new_customers, avg_purchases_per_customer, annual_churn_rate,
            total_customers, monthly_revenue / 1000
        ))
    end

    return forecasts
end

# Helper function to print milestone tables cleanly
function _print_milestone_table(title::String, milestones::Vector{Milestone}, header_color)
    println(title)
    if isempty(milestones)
        println("   (No milestones for this track)")
        return
    end

    df = DataFrame(
        "Seq" => [m.sequence for m in milestones],
        "Task" => [m.task for m in milestones],
        "Planned (hrs)" => [m.planned_hours for m in milestones],
        "Completion Date" => [m.milestone_date for m in milestones],
        "Buffer (hrs)" => [round(Int, m.buffer_hours) for m in milestones],
        "Status" => [m.milestone_date == "Beyond Plan" ? "⚠️ DELAYED" : "✅ ON TIME" for m in milestones]
    )
    sort!(df, "Seq")
    pretty_table(df; header_crayon=header_color, tf=tf_compact, alignment=:l, show_subheader=false)
end

function _print_resource_summary_track(title::String, total_task_hours::Int, cumulative_hours_vector::Vector{Float64})
    println(title)
    if isempty(cumulative_hours_vector)
        println("      (No hours available for this track)")
        return
    end
    available_hours = round(Int, cumulative_hours_vector[end])
    utilization = available_hours > 0 ? round(total_task_hours / available_hours * 100, digits=1) : 0.0
    buffer_hours = available_hours - total_task_hours

    println("      • Total Task Hours: $(total_task_hours)")
    println("      • Available Hours: $(available_hours)")
    println("      • Utilization: $(utilization)%")
    println("      • Buffer Hours: $(buffer_hours)")
end

# Generate summary report
function generate_summary(plan, milestones, hours, nebula_forecast, disclosure_forecast)
    dev_milestones = filter(m -> m.resource_type == "Development", milestones)
    marketing_milestones = filter(m -> m.resource_type == "Marketing", milestones)

    println("="^70)
    println("           🚀 PROJECT MILESTONE ANALYSIS 🚀")
    println("="^70)

    println("\n📘 DEFINITIONS:")
    println("   • Utilization: The percentage of available team hours consumed by planned tasks.")
    println("   • Buffer Hours: The total number of available team hours remaining after all tasks are completed.")

    dev_total = sum(m.planned_hours for m in dev_milestones)
    marketing_total = sum(m.planned_hours for m in marketing_milestones)

    _print_resource_summary_track("\n📊 RESOURCE SUMMARY:\n   🔧 DEVELOPMENT TRACK:", dev_total, hours.cumulative_dev)
    _print_resource_summary_track("\n   📈 MARKETING TRACK:", marketing_total, hours.cumulative_marketing)

    println("\n📅 HIRING & RESOURCE SCHEDULE:")
    hiring_df = DataFrame(
        "Month" => plan.months,
        "Exp. Devs" => plan.experienced_devs,
        "Intern Devs" => plan.intern_devs,
        "Exp. Marketers" => plan.experienced_marketers,
        "Intern Marketers" => plan.intern_marketers
    )
    pretty_table(hiring_df; header_crayon=crayon"bold cyan", tf=tf_compact, alignment=:l, show_subheader=false)

    _print_milestone_table("\n🎯 DEVELOPMENT MILESTONES:", dev_milestones, crayon"bold yellow")
    _print_milestone_table("\n📈 MARKETING MILESTONES:", marketing_milestones, crayon"bold yellow")

    println("\n💰 NEBULA-NLU REVENUE FORECAST (B2B2C):")
    nebula_df = DataFrame(
        "Month" => [f.month for f in nebula_forecast],
        "Revenue (k\$)" => [round(f.revenue_k; digits=1) for f in nebula_forecast],
        "New Cust." => [f.new_customers for f in nebula_forecast],
        "Total Cust." => [f.total_customers for f in nebula_forecast],
        "Avg Purchases/Cust" => [round(f.avg_purchases_per_customer; digits=2) for f in nebula_forecast],
        "Annual Churn (%)" => [round(f.annual_churn_rate * 100; digits=1) for f in nebula_forecast]
    )
    pretty_table(nebula_df; header_crayon=crayon"bold green", tf=tf_compact, alignment=:r, show_subheader=false)

    println("\n💰 DISCLOSURE-NLU REVENUE FORECAST (B2B):")
    disclosure_df = DataFrame(
        "Month" => [f.month for f in disclosure_forecast],
        "Revenue (k\$)" => [round(f.revenue_k; digits=1) for f in disclosure_forecast],
        "New Clients" => [f.new_customers for f in disclosure_forecast],
        "Total Clients" => [f.total_customers for f in disclosure_forecast],
        "Annual Churn (%)" => [round(f.annual_churn_rate * 100; digits=1) for f in disclosure_forecast]
    )
    pretty_table(disclosure_df; header_crayon=crayon"bold green", tf=tf_compact, alignment=:r, show_subheader=false)

    println("\n💼 VALUATION ANALYSIS (END OF 2026):")
    final_nebula_revenue_k = nebula_forecast[end].revenue_k
    final_disclosure_revenue_k = disclosure_forecast[end].revenue_k
    total_monthly_revenue_k = final_nebula_revenue_k + final_disclosure_revenue_k
    total_arr_m = (total_monthly_revenue_k * 12) / 1000

    println("   • Dec 2026 Combined Monthly Revenue: \$$(round(total_monthly_revenue_k, digits=1))k")
    println("   • Implied Annual Recurring Revenue (ARR): \$$(round(total_arr_m, digits=2))M")

    println("\n   --- Potential Valuation ---")
    println("   • Conservative (10x ARR): \$$(round(total_arr_m * 10, digits=1))M")
    println("   • Optimistic (15x ARR): \$$(round(total_arr_m * 15, digits=1))M")

    println("\n   --- Founder Equity Value (assuming 70% ownership pre-Series A) ---")
    founder_equity_conservative = total_arr_m * 10 * 0.70
    founder_equity_optimistic = total_arr_m * 15 * 0.70
    println("   • Conservative Estimate: \$$(round(founder_equity_conservative, digits=1))M")
    println("   • Optimistic Estimate: \$$(round(founder_equity_optimistic, digits=1))M")
end


# ========== MAIN ANALYSIS FUNCTION ==========
function run_analysis()
    println("🔄 Running Project Analysis...\n")

    # Define file paths for external data
    config_file = "config.csv"
    resource_file = "resource_plan.csv"
    tasks_file = "project_tasks.csv"

    # Load data from external files
    config = load_configuration(config_file)
    plan = load_resource_plan(resource_file, config)
    initial_tasks = load_tasks(tasks_file)

    # Calculate available resource hours first, as they are independent of tasks
    hours = calculate_resource_hours(plan)

    # Apply all business logic adjustments to the initial task list
    tasks = prepare_tasks(initial_tasks, hours)

    # Calculate milestone dates with the now-complete task list
    milestones = calculate_milestones(tasks, hours, plan.months)

    # Generate financial forecasts for both products
    nebula_forecast = model_nebula_revenue(plan)
    disclosure_forecast = model_disclosure_revenue(plan, milestones)

    # Generate report
    generate_summary(plan, milestones, hours, nebula_forecast, disclosure_forecast)

    return (plan=plan, hours=hours, milestones=milestones, tasks=tasks, nebula_forecast=nebula_forecast, disclosure_forecast=disclosure_forecast)
end

end # module ProjectAnalysis

println("✅ ProjectAnalysis module loaded. To run, use `using .ProjectAnalysis` and then call `run_analysis()`.")
