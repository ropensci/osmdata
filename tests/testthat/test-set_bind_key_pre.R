# NOTE: As of November 2022, these conditions are currently not possible, and
# can only be triggered by direct calls to the internal functions. The bind
# and key_pre parameters may be exposed in add_osm_features() in the future if
# package developers decide the option could be useful.

test_that ("set_bind_key_pre errors", {
    features <- list ("amenity" = "restaurant", "amenity" = "pub")

    expect_error (
        set_bind_key_pre (
            features = features,
            bind = rep ("=", 3)
        ),
        "bind must be length 1 or the same length as features"
    )

    expect_error (
        set_bind_key_pre (
            features = features,
            key_pre = rep ("", 3)
        ),
        "key_pre must be length 1 or the same length as features"
    )

    expect_error (
        set_bind_key_pre (key_pre = "-"),
        'key_pre must only include "" or "~"'
    )

    expect_error (
        set_bind_key_pre (bind = "-"),
        'bind must only include "=", "!=", "~", or "!~"'
    )
})
