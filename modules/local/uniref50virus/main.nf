process UNIREF50VIRUS {
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b42aefebb4f496d83f832ea6ce13b79cd893b62d2b80dcd9bc5c9784b0e9ff0/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-b865a00d19ef4129_1?_gl=1*xzbm5g*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.
    storeDir "${params.db_dir}/uniref50virus/${new java.util.Date().format('yyyy_MM')}"
    tag "UniRef50 viruses v${new java.util.Date().format('yyyy_MM')}"
    
    output:
    path("uniref50_virus.faa.gz")   , emit: faa_gz

    script:
    """
    # download uniref50 representatives with virus taxonomy
    get_uniref50_virus.py

    # gzip fasta
    gzip uniref50_virus.faa
    """
}
