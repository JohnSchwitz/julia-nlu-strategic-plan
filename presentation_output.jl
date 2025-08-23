# presentation_output.jl (complete with all stochastic parameters)
module PresentationOutput

using Random, Distributions, StatsPlots, Formatting
import ..LoadFactors: ResourcePlan, ProjectTask, Milestone, MonthlyForecast, DisclosureForecast, LinguaForecast
export generate_spreadsheet_output, generate_distribution_plots, generate_revenue_variability_plot

function generate_spreadsheet_output(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    println("# 🚀 NLU PORTFOLIO STRATEGIC PLAN 🚀")
    println("\n## TABLE OF CONTENTS\n")
    println("1. [📘 Definitions](#definitions)")
    println("2. [📊 Resource Summary](#resource-summary)")
    println("3. [🎯 Milestone Schedule](#milestone-schedule)")
    println("4. [📅 Hiring & Resource Schedule](#hiring-resource-schedule)")
    println("5. [🎲 Probability Analysis & Business Model Parameters](#probability-analysis)")
    println("6. [📈 NLU Activity Indicators](#activity-indicators)")
    println("7. [💰 NLU Revenue by Product](#revenue-by-product)")
    println("8. [🏪 NLU Revenue by Channel](#revenue-by-channel)")
    println("9. [💼 Valuation Analysis](#valuation-analysis)")
    println("10. [📋 Stochastic Parameters](#stochastic-parameters)")

    println("\n\n## 📘 DEFINITIONS")
    println("\n• **Utilization**: The percentage of available team capacity consumed by planned tasks within the project timeline")
    println("\n• **Buffer Capacity**: Available team capacity remaining after all planned tasks are completed. This provides schedule flexibility for scope changes or delays")

    # RESOURCE SUMMARY
    println("\n\n## 📊 RESOURCE SUMMARY")
    hours_per_month = 240
    tracks = ["Development", "Marketing"]
    total_months = [round(Int, sum(t.planned_hours for t in initial_tasks if t.task_type == track) / hours_per_month) for track in tracks]
    available_months = [round(Int, hours.cumulative_dev[end] / hours_per_month), round(Int, hours.cumulative_marketing[end] / hours_per_month)]
    utilization = [round(Int, (total_months[i] / available_months[i]) * 100) for i in 1:2]
    buffer = available_months .- total_months

    println("Track\tTotal Task Months\tAvailable Capacity\tUtilization %\tBuffer Months")
    println("Development\t$(total_months[1])\t$(available_months[1])\t$(utilization[1])%\t$(buffer[1])")
    println("Marketing\t$(total_months[2])\t$(available_months[2])\t$(utilization[2])%\t$(buffer[2])")

    # MILESTONE SCHEDULE
    println("\n\n## 🎯 MILESTONE SCHEDULE")
    strategic_map = [
        ("Infrastructure Complete", ["Infrastructure"]),
        ("Nebula-NLU MVP", ["Nebula-NLU MVP"]),
        ("Disclosure-NLU MVP", ["Disclosure - Doc Upload", "Disclosure - Preprocessing", "Disclosure - Batch System", "Disclosure - VS2.0 Integration", "Disclosure - Query Engine", "Disclosure - Gemini Summaries", "Disclosure - BFF API", "Disclosure - Attorney Dashboard", "Disclosure - Case Management", "Disclosure - Advanced Search UI", "Disclosure - Doc Viewer", "Disclosure - Mobile UI"]),
        ("Nebula-NLU Scale", ["Nebula-NLU Scale"]),
        ("Marketing Foundation", ["Mktg Digital Foundation"]),
        ("Content & Lead Generation", ["Content & Lead Generation"]),
        ("Advanced Marketing Operations", ["Advanced Operations"]),
        ("Lingua-NLU MVP", ["Lingua-NLU MVP"]),
        ("Disclosure-NLU Enterprise", ["Disclosure - Multi-user Mgmt", "Disclosure - Security/Compliance", "Disclosure - Integrations", "Disclosure - Analytics", "Disclosure - Custom Deployment", "Disclosure - Advanced Legal AI", "Disclosure - Large Law Firm Feat", "Disclosure - Conference Platform", "Disclosure - Corp Legal Tools", "Disclosure - Market Expansion"])
    ]

    aug_2025_idx = findfirst(==("Aug 2025"), plan.months)
    println("Milestone\tComponents\tCompletion Date\tStatus")
    for (name, components) in strategic_map
        component_milestones = filter(m -> m.task in components, milestones)
        if !isempty(component_milestones)
            dates = [m.milestone_date for m in component_milestones]
            month_indices = [findfirst(==(d), plan.months) for d in dates if d != "Beyond Plan"]
            final_date = isempty(month_indices) ? "Beyond Plan" : plan.months[maximum(month_indices)]
            current_milestone_idx = findfirst(==(final_date), plan.months)
            status = "ON TIME"
            if final_date == "Beyond Plan"
                status = "DELAYED"
            elseif current_milestone_idx !== nothing && aug_2025_idx !== nothing && current_milestone_idx > aug_2025_idx
                status = "PLANNED"
            end
            comp_str = length(components) > 2 ? "$(components[1]) ... $(components[end])" : join(components, ", ")
            println("$(name)\t$(comp_str)\t$(final_date)\t$(status)")
        end
    end

    # HIRING SCHEDULE
    println("\n\n## 📅 HIRING & RESOURCE SCHEDULE")
    println("Month\tExp. Devs\tIntern Devs\tExp. Marketers\tIntern Marketers")
    for i in 1:length(plan.months)
        println("$(plan.months[i])\t$(plan.experienced_devs[i])\t$(plan.intern_devs[i])\t$(plan.experienced_marketers[i])\t$(plan.intern_marketers[i])")
    end

    # COMPLETE PROBABILITY DOCUMENTATION
    println("\n\n## 🎲 PROBABILITY ANALYSIS & BUSINESS MODEL PARAMETERS")
    println("="^60)
    println("This section documents the statistical models used for the simulation.")
    nebula_p = prob_params["Nebula-NLU"]
    disclosure_p = prob_params["Disclosure-NLU"]
    lingua_p = prob_params["Lingua-NLU"]

    doc_string = """
    ### NEBULA-NLU STOCHASTIC MODEL
    **Customer Acquisition**: Poisson Distribution with Compound Growth
    - Oct 2025: λ = $(round(Int, nebula_p["lambda_oct_2025"]))
    - Jan 2026: λ = $(round(Int, nebula_p["lambda_jan_2026"]))  
    - Jul 2026: λ = $(round(Int, nebula_p["lambda_jul_2026"]))
    - 12M Compound Growth: $(plan.nebula_12m_growth)x
    - 24M Compound Growth: $(plan.nebula_24m_growth)x
    **Purchase Behavior**: Beta Distribution (α=$(nebula_p["alpha_purchase"]), β=$(nebula_p["beta_purchase"]))
    - Mean purchase rate: $(round(nebula_p["alpha_purchase"] / (nebula_p["alpha_purchase"] + nebula_p["beta_purchase"]) * 100, digits=1))%
    **Annual Churn**: Beta Distribution (α=$(nebula_p["alpha_churn"]), β=$(nebula_p["beta_churn"]))
    - Mean annual churn rate: $(round(nebula_p["alpha_churn"] / (nebula_p["alpha_churn"] + nebula_p["beta_churn"]) * 100, digits=1))%
    **Revenue Model**: \$10/month per customer with purchase conversion

    ### DISCLOSURE-NLU STOCHASTIC MODEL
    **Firm Acquisition**: Poisson Distribution with Compound Growth
    - Solo Firms: λ = $(disclosure_p["lambda_solo_firms"])
    - Small Firms: λ = $(disclosure_p["lambda_small_firms"])
    - Medium Firms: λ = $(disclosure_p["lambda_medium_firms"])
    - 12M Compound Growth: $(plan.disclosure_12m_growth)x
    - 24M Compound Growth: $(plan.disclosure_24m_growth)x
    **Revenue Model**: Multiplier-based subscription
    - Base Cost: \$$(round(Int, disclosure_p["base_monthly_cost"]))
    - Revenue Multipliers: Solo=$(disclosure_p["solo_revenue_multiplier"])x, Small=$(disclosure_p["small_revenue_multiplier"])x, Medium=$(disclosure_p["medium_revenue_multiplier"])x
    **Churn Model**: Beta Distribution (α=1, β=15) - Low churn for legal professionals
    - Mean monthly churn: ~6.25%
    **Sales Start**: 2 months after Disclosure MVP completion

    ### LINGUA-NLU STOCHASTIC MODEL  
    **Premium User Acquisition**: Poisson Distribution with Compound Growth
    - Jul 2026: λ = $(lingua_p["lambda_premium_users_jul"])
    - Dec 2026: λ = $(lingua_p["lambda_premium_users_dec"])
    - 12M Compound Growth: $(plan.lingua_12m_growth)x
    - 24M Compound Growth: $(plan.lingua_24m_growth)x
    **Match Success**: Beta Distribution (α=$(lingua_p["alpha_match_success"]), β=$(lingua_p["beta_match_success"]))
    - Mean match success rate: $(round(lingua_p["alpha_match_success"] / (lingua_p["alpha_match_success"] + lingua_p["beta_match_success"]) * 100, digits=1))%
    **Revenue Model**: \$59 per successful professional match
    **Churn Model**: Beta Distribution (α=1, β=15) - Similar to Disclosure
    **Sales Start**: 1 month after Lingua MVP completion

    ### COMPOUND GROWTH METHODOLOGY
    **First 12 Months**: Growth = base_value × (growth_factor^(month/12))
    **Next 12 Months**: Growth = base_value × first_12m_growth × (growth_24m_factor^((month-12)/12))
    This creates accelerating growth in early months, then sustained growth in later months.

    ### SALES RESOURCE ALLOCATION
    **Marketing Foundation Impact**: 1 experienced marketer (240 hours/month) allocated to sales activities after Marketing Foundation milestone completion.
    This reduces available marketing capacity for development tasks but enables revenue generation.
    """
    println(doc_string)

    # ACTIVITY INDICATORS
    println("\n\n## 📈 NLU ACTIVITY INDICATORS")
    nebula_mvp_idx = findfirst(f -> f.revenue_k > 0, nebula_f)
    nebula_mvp_idx = nebula_mvp_idx === nothing ? length(nebula_f) + 1 : nebula_mvp_idx

    println("\n### NEBULA-NLU CUSTOMER METRICS")
    println("Month\tNew Customers\tTotal Customers\tActive Users")
    for (i, f) in enumerate(nebula_f)
        new_cust = i < nebula_mvp_idx ? "pre-MVP" : string(f.new_customers)
        total_cust = i < nebula_mvp_idx ? "pre-MVP" : string(f.total_customers)
        active_users = i < nebula_mvp_idx ? "pre-MVP" : string(round(Int, f.total_customers * (1 - (1 - (1 - f.annual_churn_rate)^(1 / 12)))))
        println("$(f.month)\t$(new_cust)\t$(total_cust)\t$(active_users)")
    end

    disclosure_mvp_idx = findfirst(f -> f.revenue_k > 0, disclosure_f)
    disclosure_mvp_idx = disclosure_mvp_idx === nothing ? length(disclosure_f) + 1 : disclosure_mvp_idx

    println("\n### DISCLOSURE-NLU LEGAL FIRM METRICS")
    println("Month\tSolo Firms\tSmall Firms\tMedium Firms\tTotal Firms")
    for (i, f) in enumerate(disclosure_f)
        solo = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_solo)
        small = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_small)
        medium = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_medium)
        total = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_clients)
        println("$(f.month)\t$(solo)\t$(small)\t$(medium)\t$(total)")
    end

    println("\n### LINGUA-NLU PROFESSIONAL NETWORK METRICS")
    println("Month\tActive Pairs")
    lingua_map = Dict(f.month => f for f in lingua_f)
    for month_name in plan.months
        if haskey(lingua_map, month_name)
            f = lingua_map[month_name]
            pairs = f.revenue_k > 0 ? format(f.active_pairs, commas=false) : "pre-MVP"
            println("$(month_name)\t$(pairs)")
        end
    end

    # REVENUE BY PRODUCT
    println("\n\n## 💰 NLU REVENUE BY PRODUCT")
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    println("Month\tNebula-NLU (k\$)\tDisclosure-NLU (k\$)\tLingua-NLU (k\$)\tTOTAL (k\$)")
    for month_name in plan.months
        neb_rev = get(nebula_map, month_name, 0.0)
        dis_rev = get(disclosure_map, month_name, 0.0)
        lin_rev = get(lingua_map, month_name, 0.0)
        total_rev = neb_rev + dis_rev + lin_rev
        neb_str = neb_rev > 0 ? string(round(Int, neb_rev)) : "pre-MVP"
        dis_str = dis_rev > 0 ? string(round(Int, dis_rev)) : "pre-MVP"
        lin_str = lin_rev > 0 ? string(round(Int, lin_rev)) : "pre-MVP"
        total_str = total_rev > 0 ? string(round(Int, total_rev)) : "pre-MVP"
        println("$(month_name)\t$(neb_str)\t$(dis_str)\t$(lin_str)\t$(total_str)")
    end

    # REVENUE BY CHANNEL
    println("\n\n## 🏪 NLU REVENUE BY CHANNEL")

    println("\n### NEBULA-NLU REVENUE BY CHANNEL")
    println("Month\tRetirement Homes (k\$)\tLibraries (k\$)\tDigital Marketing (k\$)\tReferrals (k\$)")
    for month_name in plan.months
        println("$(month_name)\tpre-MVP\tpre-MVP\tpre-MVP\tpre-MVP")
    end

    println("\n### DISCLOSURE-NLU REVENUE BY CHANNEL")
    println("Month\tSolo Firms (k\$)\tSmall Firms (k\$)\tMedium Firms (k\$)\tReferrals (k\$)")
    disclosure_map = Dict(f.month => f for f in disclosure_f)
    for month_name in plan.months
        if haskey(disclosure_map, month_name)
            f = disclosure_map[month_name]
            if f.revenue_k > 0
                solo_rev = round(Int, f.total_solo * 99 * 1.0 / 1000)
                small_rev = round(Int, f.total_small * 99 * 3.0 / 1000)
                medium_rev = round(Int, f.total_medium * 99 * 13.1 / 1000)
                println("$(month_name)\t$(solo_rev)\t$(small_rev)\t$(medium_rev)\t0")
            else
                println("$(month_name)\tpre-MVP\tpre-MVP\tpre-MVP\tpre-MVP")
            end
        else
            println("$(month_name)\tpre-MVP\tpre-MVP\tpre-MVP\tpre-MVP")
        end
    end

    println("\n### LINGUA-NLU REVENUE BY CHANNEL")
    println("Month\tDigital Marketing (k\$)\tInside Referrals (k\$)\tOutside Referrals (k\$)")
    for month_name in plan.months
        println("$(month_name)\tpre-MVP\tpre-MVP\tpre-MVP")
    end

    # VALUATION ANALYSIS
    println("\n\n## 💼 VALUATION ANALYSIS")

    # Mar 2026 Valuation
    println("\n### MAR 2026 VALUATION")
    neb_rev = get(Dict(f.month => f.revenue_k for f in nebula_f), "Mar 2026", 0.0)
    dis_rev = get(Dict(f.month => f.revenue_k for f in disclosure_f), "Mar 2026", 0.0)
    lin_rev = get(Dict(f.month => f.revenue_k for f in lingua_f), "Mar 2026", 0.0)
    total_rev_k = neb_rev + dis_rev + lin_rev
    arr_m = (total_rev_k * 12) / 1000

    println("Metric\tValue")
    println("Combined Monthly Revenue\t\$$(round(Int, total_rev_k))k")
    println("Implied Annual Recurring Revenue (ARR)\t\$$(round(arr_m, digits=2))M")
    println("Conservative Valuation (8x ARR)\t\$$(round(arr_m * 8, digits=1))M")
    println("Optimistic Valuation (12x ARR)\t\$$(round(arr_m * 12, digits=1))M")
    println("Founder Equity - Conservative\t\$$(round(arr_m * 8 * 0.85, digits=1))M")
    println("Founder Equity - Optimistic\t\$$(round(arr_m * 12 * 0.85, digits=1))M")

    # Dec 2026 Valuation
    println("\n### DEC 2026 VALUATION")
    neb_rev = get(Dict(f.month => f.revenue_k for f in nebula_f), "Dec 2026", 0.0)
    dis_rev = get(Dict(f.month => f.revenue_k for f in disclosure_f), "Dec 2026", 0.0)
    lin_rev = get(Dict(f.month => f.revenue_k for f in lingua_f), "Dec 2026", 0.0)
    total_rev_k = neb_rev + dis_rev + lin_rev
    arr_m = (total_rev_k * 12) / 1000

    println("Metric\tValue")
    println("Combined Monthly Revenue\t\$$(round(Int, total_rev_k))k")
    println("Implied Annual Recurring Revenue (ARR)\t\$$(round(arr_m, digits=2))M")
    println("Conservative Valuation (10x ARR)\t\$$(round(arr_m * 10, digits=1))M")
    println("Optimistic Valuation (15x ARR)\t\$$(round(arr_m * 15, digits=1))M")
    println("Founder Equity - Conservative\t\$$(round(arr_m * 10 * 0.70, digits=1))M")
    println("Founder Equity - Optimistic\t\$$(round(arr_m * 15 * 0.70, digits=1))M")

    println("\n\n## 📋 STOCHASTIC PARAMETERS")
    println("See Probability Analysis section above for detailed parameter documentation.")
    println("\n\n✅ Data generation complete.")
    println("ℹ️ To visualize distributions, call `generate_distribution_plots(results.prob_params)` after capturing the output of `run_analysis()`.")
end

# ========== VISUALIZATION (Manual Execution) ==========
function generate_distribution_plots(prob_parameters::Dict{String,Dict{String,Float64}})
    println("✅ Generating distribution plots...")
    Random.seed!(42)
    nebula_p = prob_parameters["Nebula-NLU"]
    poisson_customers = Poisson(nebula_p["lambda_jan_2026"])
    beta_purchase = Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])
    beta_churn = Beta(nebula_p["alpha_churn"], nebula_p["beta_churn"])
    customer_draws = [rand(poisson_customers) for _ in 1:10]
    purchase_draws = [rand(beta_purchase) for _ in 1:10]
    churn_draws = [rand(beta_churn) for _ in 1:10]
    p1 = plot(poisson_customers, (poisson_customers.λ-40):(poisson_customers.λ+40), title="Customer Acquisition\nPoisson(λ=$(round(Int,poisson_customers.λ)))", xlabel="New Customers", ylabel="Probability", lw=3, legend=false)
    scatter!(p1, customer_draws, [pdf(poisson_customers, x) for x in customer_draws], ms=5, color=:red)
    p2 = plot(beta_purchase, 0:0.01:1, title="Purchase Rate\nBeta(α=$(beta_purchase.α), β=$(beta_purchase.β))", xlabel="Purchase Rate", ylabel="Density", lw=3, color=:green, legend=false)
    scatter!(p2, purchase_draws, [pdf(beta_purchase, x) for x in purchase_draws], ms=5, color=:red)
    p3 = plot(beta_churn, 0:0.01:1, title="Annual Churn Rate\nBeta(α=$(beta_churn.α), β=$(beta_churn.β))", xlabel="Annual Churn Rate", ylabel="Density", lw=3, color=:purple, legend=false)
    scatter!(p3, churn_draws, [pdf(beta_churn, x) for x in churn_draws], ms=5, color=:red)
    display(plot(p1, p2, p3, layout=(1, 3), size=(1200, 350), plot_title="Key Revenue Driver Distributions with 10 Sample Draws (Nebula-NLU)"))
end

function generate_revenue_variability_plot(nebula_f, disclosure_f, lingua_f, prob_parameters)
    println("✅ Generating revenue variability plot...")
    Random.seed!(123)
    n_scenarios = 10
    nebula_p = prob_parameters["Nebula-NLU"]
    disclosure_p = prob_parameters["Disclosure-NLU"]
    lingua_p = prob_parameters["Lingua-NLU"]
    final_nebula_customers = nebula_f[end].total_customers
    final_disclosure_clients = disclosure_f[end]
    final_lingua_users = round(Int, lingua_f[end].active_pairs / get(prob_parameters["Lingua-NLU"], "mean_match_success", 0.6))
    scenarios = []
    for i in 1:n_scenarios
        nebula_revenue = final_nebula_customers * rand(Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])) * 10.0
        disclosure_revenue = (final_disclosure_clients.total_solo * disclosure_p["solo_revenue_multiplier"] + final_disclosure_clients.total_small * disclosure_p["small_revenue_multiplier"] + final_disclosure_clients.total_medium * disclosure_p["medium_revenue_multiplier"]) * disclosure_p["base_monthly_cost"] * (1 + 0.1 * (rand() - 0.5))
        lingua_revenue = final_lingua_users * rand(Beta(lingua_p["alpha_match_success"], lingua_p["beta_match_success"])) * 59.0
        push!(scenarios, (nebula=nebula_revenue / 1000, disclosure=disclosure_revenue / 1000, lingua=lingua_revenue / 1000))
    end
    nebula_revs = [s.nebula for s in scenarios]
    disclosure_revs = [s.disclosure for s in scenarios]
    lingua_revs = [s.lingua for s in scenarios]
    p = groupedbar([nebula_revs disclosure_revs lingua_revs], bar_position=:dodge, title="Revenue Variability - 10 Independent Scenarios (Dec 2026)", xlabel="Scenario Number", ylabel="Revenue (k\$)", labels=["Nebula-NLU" "Disclosure-NLU" "Lingua-NLU"], size=(1000, 500), lw=0)
    display(p)
end

end # module PresentationOutput