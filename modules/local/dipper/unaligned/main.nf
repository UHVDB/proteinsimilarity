process DIPPER_UNALIGNED {
    tag "${meta.id}"
    label 'process_gpu'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a0/a08b1c0eee51d2d0bd1dc461d636ae9f5ee0a642c64aa354e7c8f0e5eb735651/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-44b81846f9b14458_1?_gl=1*gmwsbu*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.
    storeDir "${params.output_dir}/${params.new_release_id}/compare/phylogeny"
    

    input:
    tuple val(meta) , path(fna_gz), path(nwk_gz)

    output:
    tuple val(meta) , path("${meta.id}.dipper.nwk.gz")   , emit: nwk_gz

    script:
    def update_tree = nwk_gz ? "--add --input-tree ${nwk_gz}" : ""
    """
    ### Create tree
    dipper \\
        --input-format r \\
        --input-file ${fna_gz} \\
        --output-format t \\
        --output-file ${meta.id}.dipper.nwk \\
        ${update_tree}

    ### Compress
    pigz -p ${task.cpus} ${meta.id}.dipper.nwk
    """
}
