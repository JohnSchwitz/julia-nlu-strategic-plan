# test_table_formats.jl
println("=== TABLE FORMAT TESTING ===")

# Test data: 3 rows, 3 columns
headers = ["Name", "Age", "City"]
data = [
    ["Alice", 25, "New York"],
    ["Bob", 30, "London"],
    ["Carol", 35, "Tokyo"]
]

println("\n1. METHOD 1: Standard println with \\t")
println("Name\tAge\tCity")
println("Alice\t25\tNew York")
println("Bob\t30\tLondon")
println("Carol\t35\tTokyo")

println("\n2. METHOD 2: String interpolation with tab character")
println("$(headers[1])\t$(headers[2])\t$(headers[3])")
for row in data
    println("$(row[1])\t$(row[2])\t$(row[3])")
end

println("\n3. METHOD 3: join() function with tab")
println(join(headers, "\t"))
for row in data
    println(join(row, "\t"))
end

println("\n4. METHOD 4: Comma separated")
println(join(headers, ","))
for row in data
    println(join(row, ","))
end

println("\n5. METHOD 5: Using Char(9) explicit tab")
println("$(headers[1])$(Char(9))$(headers[2])$(Char(9))$(headers[3])")
for row in data
    println("$(row[1])$(Char(9))$(row[2])$(Char(9))$(row[3])")
end

println("\n6. METHOD 6: Pipe separated")
println(join(headers, "|"))
for row in data
    println(join(row, "|"))
end

println("\n=== END TESTING ===")