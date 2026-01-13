process PADLOC_PADLOC {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/76/768bab7734b2fb5b08fcebde976e60de5c423eea9efa201a4950249ee0b2b9b6/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-5b6a28e17ef90d6b_1?_gl=1*1ubap32*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..
    containerOptions "--bind ./padloc_db:/opt/conda/bin/../data"

    input:
    tuple val(meta) , path(faa), path(gff)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.padloc.csv.gz")   , emit: csv_gz  , optional: true

    script:
    """
    # create output directory
    mkdir -p ./padloc_out

    gunzip -f ${faa}
    gunzip -f ${gff}

    # run padloc
    padloc \\
        --faa ${faa.getBaseName()} \\
        --gff ${gff.getBaseName()} \\
        --outdir padloc_out \\
        --cpu ${task.cpus}
    
    rm -rf ${faa.getBaseName()} ${gff.getBaseName()}

    # move desired output files to appropriate location
    if [ ! -s padloc_out/*.csv ]; then
        echo "No defense systems found"
        touch ${meta.id}.padloc.csv
        gzip ${meta.id}.padloc.csv
    else
        mv padloc_out/*_padloc.csv ${meta.id}.padloc.csv
        gzip ${meta.id}.padloc.csv
    fi

    rm -rf padloc_out
    """
}
