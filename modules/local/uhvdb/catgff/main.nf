process UHVDB_CATGFF {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e2/e2c4102e2b440c4ae338823d50869110b0523748cb7e3361c216956554f22cbc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-c003348b5b3273b4_1?_gl=1*15l3vox*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.
    storeDir "${publish_dir}/${meta.id}"
    

    input:
    tuple val(meta) , path(files)
    val(publish_dir)

    output:
    tuple val(meta) , path("${meta.id}.gff.gz")   , emit: combined

    script:
    """
    ### Combine files ###
    for file in ${files}; do
        zcat \$file | grep "^#" >> ${meta.id}.gff
    done

    for file in ${files}; do
        if [ \$(zcat \$file | grep -v "^#" | wc -l) -gt 0 ]; then
            zcat \$file | grep -v "^#" >> ${meta.id}.gff
        else
            echo "File \$file has no GFF entries; skipping content append."
        fi
    done

    pigz -p ${task.cpus} ${meta.id}.gff
    """
}
