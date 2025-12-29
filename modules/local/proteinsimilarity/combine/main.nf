process PROTEINSIMILARITY_COMBINE {
    tag "${meta.id}"
    label 'process_single'
    container "docker://mambaorg/micromamba:git-eb92c8f-debian12"

    input:
    tuple val(meta), path(tsv_gzs)

    output:
    tuple val(meta), path("${meta.id}.combined_normscore.tsv.gz")   , emit: tsv_gz

    script:
    """
    touch ${meta.id}.combined_normscore.tsv.gz

    # iterate over scores
    for table in ${tsv_gzs}; do
        cat \${table} >> ${meta.id}.combined_normscore.tsv.gz
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        touch: \$( touch --version | sed -e "s/touch (GNU coreutils) //g" )
        cat: \$( cat --version | sed -e "s/cat (GNU coreutils) //g" )
    END_VERSIONS
    """
}
