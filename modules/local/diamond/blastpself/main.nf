process DIAMOND_BLASTPSELF {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c8/c8f2bfa934e16ca7057b29dc5662b7610df006b952a16dea8cfa996d41205c98/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-2cf0e5b219980c3d_1?_gl=1*1gf7it2*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), path(faa)

    output:
    tuple val(meta), path("${meta.id}.diamond_blastp.tsv.gz")   , emit: tsv_gz

    script:
    """
    # make DIAMOND db for self alignment
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in ${faa} \\
        -d ${meta.id}

    # align genes to DIAMOND self db
    diamond \\
        blastp \\
        --masking none \\
        -k 1000 \\
        -e 1e-3 \\
        --faster \\
        --query ${faa} \\
        --db ${meta.id}.dmnd \\
        --threads ${task.cpus} \\
        --outfmt 6 \\
        --out ${meta.id}.diamond_blastp.tsv

    gzip ${meta.id}.diamond_blastp.tsv

    # clean tmp files
    rm -rf ${meta.id}.dmnd

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        diamond: \$(diamond --version 2>&1 | tail -n 1 | sed 's/^diamond version //')
    END_VERSIONS

    """
}
