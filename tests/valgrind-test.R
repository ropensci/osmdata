vg_check <- function () {
    vg <- system2 (command = "R",
                   args = c ('-d "valgrind --tool=memcheck --leak-check=full"', # nolint
                             '-f valgrind-script.R'),                           # nolint
                   stdout = TRUE, stderr = TRUE)

    lost <- NULL
    types <- c ("definitely lost", "indirectly lost", "possibly lost")
    for (ty in types) {
        lost_type <- which (grepl (ty, vg))
        n <- regmatches (vg [lost_type],
                         gregexpr ("[[:digit:]]+", vg [lost_type]))
        lost <- c (lost, as.numeric (n [[1]] [2:3]))
    }
    if (any (lost > 0))
        stop ("valgrind memory leaks detected!")

    return (TRUE)
}
