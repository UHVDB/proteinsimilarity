process PHIST_ARIA2C {
    tag "${meta.id}"
    label "process_super_high"
    maxForks 50
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2d/2da893faa291c2c37400521fb3fa380961985fef70dcda9d250eb469ec90ca31/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-3d125c4d72f5a9ac_1?_gl=1*13x4irc*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , val(urls)
    tuple val(meta2), path(virus_db)

    output:
    tuple val(meta), path("${meta.id}.phist.csv.gz")    , emit: csv_gz

    script:
    def download_list   = urls.collect { url -> url.toString() }.join(',')
    """
    # create an input file for aria2c
    IFS=',' read -r -a download_array <<< "${download_list}"
    printf '%s\\n' "\${download_array[@]}" > aria2_file.tsv

    # download fasta files with aria2c
    aria2c \\
        --input=aria2_file.tsv \\
        --dir=host_fastas \\
        --max-concurrent-downloads=${task.cpus}

    # run phist on virus fasta and host fasta chunk
    phist.py \\
        ${virus_db} \\
        host_fastas/ \\
        ${meta.id}.phist.csv \\
        ${meta.id}.phist_preds.csv \\
        -t ${task.cpus}

    gzip ${meta.id}.phist.csv

    rm -rf ${meta.id}.phist_preds.csv host_fastas/
    """
}
