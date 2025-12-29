process PHAROKKA_INSTALLDATABASES {
    tag "pharokka_db"
    label 'process_single'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e8fd5a881f4f4dd544da48510ca945aa398342fd1439548cea09176d4b47c25/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-4ed8eb0e60aaf382_1?_gl=1*gojbf9*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.
    storeDir "${params.db_dir}/pharokka"

    output:
    path("pharokka_db/")   , emit: db

    script:
    """
    # download pharokka database
    install_databases.py \\
        -o pharokka_db
    """
}
