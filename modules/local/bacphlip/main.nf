process BACPHLIP {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2c/2c527b78d922f59ba27a41a385d3728a34a8dc0d059723a0931d8fef2a83d404/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7498a9ac2656f4d_1?_gl=1*t4cvxp*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.

    input:
    tuple val(meta), path(fna_gz)

    output:
    tuple val(meta) , path("${meta.id}.bacphlip.tsv.gz") , emit: tsv_gz

    script:
    """
    ### Gunzip FNA ###
    gunzip -c ${fna_gz} > ${fna_gz.getBaseName()}

    ### Run BACPHLIP ###
    bacphlip \\
        --input_file ${fna_gz.getBaseName()} \\
        --force_overwrite \\
        --multi_fasta

    ### Compress
    mv ${fna_gz.getBaseName()}.bacphlip ${meta.id}.bacphlip.tsv
    gzip ${fna_gz.getBaseName()}.bacphlip.tsv

    ### Cleanup
    rm -rf ${fna_gz.getBaseName()} ${fna_gz.getBaseName()}.BACPHLIP_DIR/ ${fna_gz.getBaseName()}.hmmsearch.tsv
    """
}
