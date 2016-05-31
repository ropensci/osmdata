context ('get-nodes')

test_that ('url_download', {
           expect_error (get_nodes (url_download=NULL),
                           "url_download must be character class")
           expect_error (get_nodes (url_download=1),
                           "url_download must be character class")
})

