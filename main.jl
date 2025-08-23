# main.jl (updated with proper sales effort handling)
module ProjectAnalysis

using Random
include("load_factors.jl")
include("stochastic_model.jl")
include("presentation_output.jl")

using .LoadFactors
using .StochasticModel
using .PresentationOutput

export run_analysis, generate_distribution_plots, generate_revenue_variability_plot

# ========== MAIN ANALYSIS FUNCTION ==========
function run_analysis()
    Random.seed!(42)
    config_file = "config.csv"
    resource_file = "resource_plan.csv"
    tasks_file = "project_tasks.csv"
    prob_params_file = "probability_parameters.csv"

    config = load_configuration(config_file)
    plan = load_resource_plan(resource_file, config)
    initial_tasks = load_tasks(tasks_file)
    prob_params = load_probability_parameters(prob_params_file)

    # First pass: calculate milestones without sales deduction to find Marketing Foundation completion
    initial_hours = (monthly_dev=(plan.experienced_devs .* plan.dev_productivity_factor .+
                                  plan.intern_devs .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.dev_efficiency,
        monthly_marketing=(plan.experienced_marketers .* plan.marketing_productivity_factor .+
                           plan.intern_marketers .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.marketing_efficiency)
    initial_hours = (monthly_dev=initial_hours.monthly_dev,
        monthly_marketing=initial_hours.monthly_marketing,
        cumulative_dev=cumsum(initial_hours.monthly_dev),
        cumulative_marketing=cumsum(initial_hours.monthly_marketing))

    milestone_tasks = prepare_tasks_for_milestones(initial_tasks, initial_hours)
    temp_milestones = calculate_milestones(milestone_tasks, initial_hours, plan.months)

    # Now calculate final hours with sales deduction
    hours = calculate_resource_hours(plan, temp_milestones)

    # Recalculate milestones with adjusted hours
    milestone_tasks = prepare_tasks_for_milestones(initial_tasks, hours)
    milestones = calculate_milestones(milestone_tasks, hours, plan.months)

    nebula_forecast = model_nebula_revenue(plan, prob_params["Nebula-NLU"])
    disclosure_forecast = model_disclosure_revenue(plan, milestones, prob_params["Disclosure-NLU"])
    lingua_forecast = model_lingua_revenue(plan, milestones, prob_params["Lingua-NLU"])

    generate_spreadsheet_output(plan, milestones, initial_tasks, hours, nebula_forecast, disclosure_forecast, lingua_forecast, prob_params)

    return (plan=plan, milestones=milestones, tasks=milestone_tasks, hours=hours, nebula_forecast=nebula_forecast, disclosure_forecast=disclosure_forecast, lingua_forecast=lingua_forecast, prob_params=prob_params)
end

end # module ProjectAnalysis