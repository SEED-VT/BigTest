# Run actual big test
export BigTest=$(realpath $(dirname ${BASH_SOURCE}))
echo BigTest Path: $BigTest

dependencies=$CLASSPATH
dependencies=$dependencies:$BigTest/jpf-core/build/*
dependencies=$dependencies:$BigTest/jpf-symbc/build/*
dependencies=$dependencies:$BigTest/SymExec/bin/*
dependencies=$dependencies:$BigTest/UDFExtractor/bin/*

declare -A binpath
BenchmarksFault=`realpath $BigTest/BenchmarksFault/bin/`
binpath["l2"]=${BenchmarksFault}/pigmixl2/L2$
binpath["wordcount"]=${BenchmarksFault}/wordcount/WordCount$
binpath["movieratings"]=${BenchmarksFault}/movieratings/MovieRatingsCount$
binpath["income"]=${BenchmarksFault}/incomeaggregate/IncomeAggregate$
#binpath["trainsit"]=${BenchmarksFault}/airporttransit/AirportTransit$
binpath["StudentGrades"]=${BenchmarksFault}/gradeanalysis/StudentGrades$
binpath["commute"]=${BenchmarksFault}/commutetype/CommuteType$

NewBench=`realpath $BigTest/../newbench/bin/`
echo new bench path: $NewBench
binpath["movie1"]=${NewBench}/movie1/movie1$
binpath["airport"]=${NewBench}/airport/airport$
binpath["usedcars"]=${NewBench}/usedcars/usedcars$
binpath["transit"]=${NewBench}/transit/transit$
binpath["credit"]=${NewBench}/credit/credit$

# Paper demos (faithful reproductions of the worked examples)
binpath["gradebook"]=${NewBench}/gradebook/gradebook$    # ICSE 2020 demo, Fig. 2
binpath["commutetrips"]=${NewBench}/commutetrips/commutetrips$  # FSE 2019, Fig. 2 (Alice/Palms)

# Additional benchmarks
binpath["weblog"]=${NewBench}/weblog/weblog$            # flatMap + reduceByKey (log events)
binpath["sales"]=${NewBench}/sales/sales$              # join + reduceByKey (revenue per category)
binpath["temps"]=${NewBench}/temps/temps$              # parse + filter + reduceByKey
#binpath["movie2"]=${NewBench}/movie2$
#binpath["grades"]=${NewBench}/grades$
# binpath["b"]=${NewBench}/b$ # 3 tables
#binpath["webpagesegmentation"]=${NewBench}/webpagesegmentation$


binpath["Q1"]=${NewBench}/Q1/Q1$
binpath["Q3"]=${NewBench}/Q3/Q3$
binpath["Q6"]=${NewBench}/Q6/Q6$
binpath["Q7"]=${NewBench}/Q7/Q7$
binpath["Q12"]=${NewBench}/Q12/Q12$
binpath["Q15"]=${NewBench}/Q15/Q15$
binpath["Q19"]=${NewBench}/Q19/Q19$
binpath["Q20"]=${NewBench}/Q20/Q20$