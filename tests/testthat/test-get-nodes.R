context ('get-nodes')

test_that ('url_download', {
           expect_error (get_nodes (), "bbox must be provided")
})

