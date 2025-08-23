# stochastic_model.jl (updated with sales effort deduction)
module StochasticModel

using Random, Distributions
import ..LoadFactors: ResourcePlan, ProjectTask, Milestone, MonthlyForecast, DisclosureForecast, LinguaForecast
export calculate_resource_hours, calculate_milestones, prepare_tasks_for_milestones
export model_nebula_revenue, model_disclosure_revenue, model_lingua_revenue

# ========== CALCULATION FUNCTIONS ==========
function calculate_resource_hours(plan::ResourcePlan, milestones::Vector{Milestone})
    monthly_dev_hours = (plan.experienced_devs .* plan.dev_productivity_factor .+
                         plan.intern_devs .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.dev_efficiency

    monthly_marketing_hours = (plan.experienced_marketers .* plan.marketing_productivity_factor .+
                               plan.intern_marketers .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.marketing_efficiency

    # Find Marketing Foundation completion month
    marketing_foundation_milestone = findfirst(m -> m.task == "Mktg Digital Foundation", milestones)
    sales_start_month = marketing_foundation_milestone !== nothing ?
                        findfirst(==(milestones[marketing_foundation_milestone].milestone_date), plan.months) :
                        nothing

    # Deduct 1 experienced marketer per month (240 hours) for sales after Marketing Foundation
    if sales_start_month !== nothing
        for i in (sales_start_month+1):length(monthly_marketing_hours)
            monthly_marketing_hours[i] -= 240  # 1 person * 30 days * 8 hours
            monthly_marketing_hours[i] = max(0, monthly_marketing_hours[i])  # Don't go negative
        end
    end

    return (monthly_dev=monthly_dev_hours,
        monthly_marketing=monthly_marketing_hours,
        cumulative_dev=cumsum(monthly_dev_hours),
        cumulative_marketing=cumsum(monthly_marketing_hours))
end

function calculate_milestones(tasks::Vector{ProjectTask}, hours, months::Vector{String})
    dev_tasks = sort(filter(t -> t.task_type == "Development", tasks), by=t -> t.sequence)
    marketing_tasks = sort(filter(t -> t.task_type == "Marketing", tasks), by=t -> t.sequence)
    milestones = Milestone[]

    function _calculate_milestones_for_type(task_list, cumulative_hours, resource_type, months)
        task_cumulative = 0
        for task in task_list
            task_cumulative += task.planned_hours
            milestone_month_idx = findfirst(h -> h >= task_cumulative, cumulative_hours)
            if milestone_month_idx !== nothing
                push!(milestones, Milestone(task.name, task.sequence, task.planned_hours, task_cumulative, months[milestone_month_idx], cumulative_hours[milestone_month_idx], cumulative_hours[milestone_month_idx] - task_cumulative, resource_type))
            else
                push!(milestones, Milestone(task.name, task.sequence, task.planned_hours, task_cumulative, "Beyond Plan", 0.0, 0.0, resource_type))
            end
        end
    end

    _calculate_milestones_for_type(dev_tasks, hours.cumulative_dev, "Development", months)
    _calculate_milestones_for_type(marketing_tasks, hours.cumulative_marketing, "Marketing", months)
    return milestones
end

function prepare_tasks_for_milestones(initial_tasks::Vector{ProjectTask}, hours)
    tasks = deepcopy(initial_tasks)
    dev_planned_total = sum(t.planned_hours for t in tasks if t.task_type == "Development")
    mktg_planned_total = sum(t.planned_hours for t in tasks if t.task_type == "Marketing")
    remaining_dev_hours = hours.cumulative_dev[end] - dev_planned_total
    remaining_mktg_hours = hours.cumulative_marketing[end] - mktg_planned_total
    next_dev_seq = isempty(filter(t -> t.task_type == "Development", tasks)) ? 1 : maximum(t.sequence for t in tasks if t.task_type == "Development") + 1
    next_mktg_seq = isempty(filter(t -> t.task_type == "Marketing", tasks)) ? 1 : maximum(t.sequence for t in tasks if t.task_type == "Marketing") + 1
    push!(tasks, ProjectTask("Future Project Development", max(0, round(Int, remaining_dev_hours)), next_dev_seq, "Development"))
    push!(tasks, ProjectTask("Executing Mktg & Sales", max(0, round(Int, remaining_mktg_hours)), next_mktg_seq, "Marketing"))
    return tasks
end

# ========== FINANCIAL MODELING WITH COMPOUND GROWTH ==========
function apply_compound_growth(base_value::Float64, month_idx::Int, growth_12m::Float64, growth_24m::Float64)
    if month_idx <= 12
        return base_value * (growth_12m^(month_idx / 12))
    else
        # First 12 months growth, then additional growth for months 13-24
        first_12_growth = growth_12m
        additional_months = month_idx - 12
        return base_value * first_12_growth * (growth_24m^(additional_months / 12))
    end
end

function model_nebula_revenue(plan::ResourcePlan, params::Dict{String,Float64})
    purchase_price = 10.0
    lambda_oct_2025 = params["lambda_oct_2025"]
    lambda_jan_2026 = params["lambda_jan_2026"]
    lambda_jul_2026 = params["lambda_jul_2026"]
    purchase_rate_dist = Beta(params["alpha_purchase"], params["beta_purchase"])
    churn_dist = Beta(params["alpha_churn"], params["beta_churn"])
    forecasts = MonthlyForecast[]
    total_customers = 0.0
    lambda = 0.0

    # Find start month index for growth calculation
    start_month_idx = findfirst(==("Oct 2025"), plan.months)

    for (i, month_name) in enumerate(plan.months)
        if month_name == "Oct 2025"
            lambda = lambda_oct_2025
        end
        if month_name == "Jan 2026"
            lambda = lambda_jan_2026
        end
        if month_name == "Jul 2026"
            lambda = lambda_jul_2026
        end

        # Apply compound growth if we have a baseline lambda
        if lambda > 0 && start_month_idx !== nothing && i >= start_month_idx
            growth_month = i - start_month_idx + 1
            lambda_adjusted = apply_compound_growth(lambda, growth_month, plan.nebula_12m_growth, plan.nebula_24m_growth)
            new_customers = rand(Poisson(lambda_adjusted))
        else
            new_customers = lambda > 0 ? rand(Poisson(lambda)) : 0
        end

        purchase_conversion_rate = rand(purchase_rate_dist)
        annual_churn_rate = rand(churn_dist)
        monthly_churn_rate = 1 - (1 - annual_churn_rate)^(1 / 12)
        customers_retained = total_customers * (1 - monthly_churn_rate)
        total_customers = customers_retained + new_customers
        monthly_revenue = total_customers * purchase_conversion_rate * purchase_price
        push!(forecasts, MonthlyForecast(month_name, new_customers, purchase_conversion_rate, annual_churn_rate, round(Int, total_customers), monthly_revenue / 1000))
    end
    return forecasts
end

function model_disclosure_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64})
    base_price = params["base_monthly_cost"]
    lambda_solo = params["lambda_solo_firms"]
    lambda_small = params["lambda_small_firms"]
    lambda_medium = params["lambda_medium_firms"]
    lambda_large = get(params, "lambda_large_firms", 0.1)
    lambda_biglaw = get(params, "lambda_biglaw", 0.0)
    rev_mult_solo = params["solo_revenue_multiplier"]
    rev_mult_small = params["small_revenue_multiplier"]
    rev_mult_medium = params["medium_revenue_multiplier"]
    rev_mult_large = get(params, "large_revenue_multiplier", 50.5)
    rev_mult_biglaw = get(params, "biglaw_revenue_multiplier", 202.0)
    mvp_milestone_idx = findfirst(m -> m.task == "Disclosure - Mobile UI", milestones)
    mvp_completion_date = mvp_milestone_idx !== nothing ? milestones[mvp_milestone_idx].milestone_date : "Beyond Plan"
    sales_start_idx = findfirst(==(mvp_completion_date), plan.months)
    sales_start_idx = sales_start_idx !== nothing ? sales_start_idx + 2 : length(plan.months) + 1
    forecasts = DisclosureForecast[]
    total_solo_clients, total_small_clients, total_medium_clients, total_large_clients, total_biglaw_clients = 0.0, 0.0, 0.0, 0.0, 0.0
    churn_dist = Beta(1, 15)

    for (i, month_name) in enumerate(plan.months)
        new_solo, new_small, new_medium, new_large, new_biglaw = 0, 0, 0, 0, 0
        if i >= sales_start_idx
            # Apply compound growth
            growth_month = i - sales_start_idx + 1
            lambda_solo_adj = apply_compound_growth(lambda_solo, growth_month, plan.disclosure_12m_growth, plan.disclosure_24m_growth)
            lambda_small_adj = apply_compound_growth(lambda_small, growth_month, plan.disclosure_12m_growth, plan.disclosure_24m_growth)
            lambda_medium_adj = apply_compound_growth(lambda_medium, growth_month, plan.disclosure_12m_growth, plan.disclosure_24m_growth)
            lambda_large_adj = apply_compound_growth(lambda_large, growth_month, plan.disclosure_12m_growth, plan.disclosure_24m_growth)
            lambda_biglaw_adj = apply_compound_growth(lambda_biglaw, growth_month, plan.disclosure_12m_growth, plan.disclosure_24m_growth)

            new_solo = rand(Poisson(lambda_solo_adj))
            new_small = rand(Poisson(lambda_small_adj))
            new_medium = rand(Poisson(lambda_medium_adj))
            new_large = rand(Poisson(lambda_large_adj))
            new_biglaw = rand(Poisson(lambda_biglaw_adj))
        end
        new_customers = new_solo + new_small + new_medium + new_large + new_biglaw
        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        total_solo_clients = total_solo_clients * (1 - monthly_churn_rate) + new_solo
        total_small_clients = total_small_clients * (1 - monthly_churn_rate) + new_small
        total_medium_clients = total_medium_clients * (1 - monthly_churn_rate) + new_medium
        total_large_clients = total_large_clients * (1 - monthly_churn_rate) + new_large
        total_biglaw_clients = total_biglaw_clients * (1 - monthly_churn_rate) + new_biglaw
        total_customers = round(Int, total_solo_clients + total_small_clients + total_medium_clients + total_large_clients + total_biglaw_clients)
        monthly_revenue = (total_solo_clients * rev_mult_solo + total_small_clients * rev_mult_small + total_medium_clients * rev_mult_medium + total_large_clients * rev_mult_large + total_biglaw_clients * rev_mult_biglaw) * base_price
        push!(forecasts, DisclosureForecast(month_name, new_customers, total_customers, round(Int, total_solo_clients), round(Int, total_small_clients), round(Int, total_medium_clients), round(Int, total_large_clients), round(Int, total_biglaw_clients), monthly_revenue / 1000))
    end
    return forecasts
end

function model_lingua_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64})
    price_per_match = 59.0
    lambda_prem_jul = params["lambda_premium_users_jul"]
    lambda_prem_dec = params["lambda_premium_users_dec"]
    match_dist = Beta(params["alpha_match_success"], params["beta_match_success"])
    churn_dist = Beta(1, 15)
    mvp_milestone_idx = findfirst(m -> m.task == "Lingua-NLU MVP", milestones)
    mvp_completion_date = mvp_milestone_idx !== nothing ? milestones[mvp_milestone_idx].milestone_date : "Beyond Plan"
    sales_start_idx = findfirst(==(mvp_completion_date), plan.months)
    sales_start_idx = sales_start_idx !== nothing ? sales_start_idx + 1 : length(plan.months) + 1
    forecasts = LinguaForecast[]
    total_premium_users = 0.0
    lambda_prem = 0.0

    for (i, month_name) in enumerate(plan.months)
        if month_name == "Jul 2026"
            lambda_prem = lambda_prem_jul
        end
        if month_name == "Dec 2026"
            lambda_prem = lambda_prem_dec
        end

        if i >= sales_start_idx && lambda_prem > 0
            # Apply compound growth
            growth_month = i - sales_start_idx + 1
            lambda_prem_adj = apply_compound_growth(lambda_prem, growth_month, plan.lingua_12m_growth, plan.lingua_24m_growth)
            new_premium_users = rand(Poisson(lambda_prem_adj))
        else
            new_premium_users = 0
        end

        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        users_retained = total_premium_users * (1 - monthly_churn_rate)
        total_premium_users = users_retained + new_premium_users
        match_success_rate = rand(match_dist)
        monthly_revenue = total_premium_users * match_success_rate * price_per_match
        push!(forecasts, LinguaForecast(month_name, round(Int, total_premium_users * match_success_rate), monthly_revenue / 1000))
    end
    return forecasts
end

end # module StochasticModel