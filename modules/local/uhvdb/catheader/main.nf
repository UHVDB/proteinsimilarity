process UHVDB_CATHEADER {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e2/e2c4102e2b440c4ae338823d50869110b0523748cb7e3361c216956554f22cbc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-c003348b5b3273b4_1?_gl=1*15l3vox*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.
    storeDir "${publish_dir}/${meta.id}"

    input:
    tuple val(meta) , path(files)   , val(lines_per_header) , val(suffix)
    val(publish_dir)

    output:
    tuple val(meta) , path("${meta.id}.${suffix}.gz")   , emit: combined

    script:
    """
    ### Print header line
    for file in ${files[0]}; do
        zcat \$file | head -n ${lines_per_header} >> ${meta.id}.${suffix}
    done

    ### Print non-header lines
    for file in ${files}; do
        if [ \$(zcat \$file | wc -l) -gt ${lines_per_header} ]; then
            zcat \$file | tail -n +${lines_per_header+1} >> ${meta.id}.${suffix}
        else
            echo "File \$file has only header line or is empty; skipping content append."
        fi
    done

    ### Compress
    pigz -p ${task.cpus} ${meta.id}.${suffix}
    """
}
