# Test Julia setup
println("🚀 Julia VS Code setup working!")

# Test plotting (should show in VS Code plot viewer)
using Plots
plot([1,2,3], [1,4,9], title="Test Plot")

# Test your resource planning code
struct TestTask
    name::String
    hours::Int
end

task = TestTask("Test Task", 100)
println("Task: $(task.name) - $(task.hours) hours")

