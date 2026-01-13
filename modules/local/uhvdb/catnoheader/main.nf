process UHVDB_CATNOHEADER {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e2/e2c4102e2b440c4ae338823d50869110b0523748cb7e3361c216956554f22cbc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-c003348b5b3273b4_1?_gl=1*15l3vox*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.
    storeDir "${publish_dir}/${meta.id}"
    
    input:
    tuple val(meta) , path(files)   , val(suffix)
    val(publish_dir)

    output:
    tuple val(meta) , path("${meta.id}.${suffix}")  , emit: combined

    script:
    """
    ### Combine files ###
    for file in ${files}; do
        if [[ \$file == *.gz ]]; then
            cat \$file >> ${meta.id}.${suffix}
        else
            gzip -c \$file >> ${meta.id}.${suffix}
        fi
    done
    """
}
