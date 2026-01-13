process PADLOC_UPDATE {
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/76/768bab7734b2fb5b08fcebde976e60de5c423eea9efa201a4950249ee0b2b9b6/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-5b6a28e17ef90d6b_1?_gl=1*1ubap32*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..
    beforeScript 'mkdir -p ./padloc_db'
    containerOptions "--bind ./padloc_db:/opt/conda/bin/../data"
    storeDir "${params.db_dir}/padloc/2.0.0"
    tag "PADLOC v2.0.0"
    

    output:
    path("padloc_db")       , emit: db

    script:
    """
    mkdir -p padloc_db
    export DATA="./padloc_db"

    # download padloc db
    padloc --db-update --data ./padloc_db
    """
}
