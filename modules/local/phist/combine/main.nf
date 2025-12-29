process PHIST_COMBINE {
    tag "${meta.id}"
    label "process_single"

    input:
    tuple val(meta) , path(csv_gzs)

    output:
    tuple val(meta), path("${meta.id}.phist_combined.csv.gz")   , emit: csv_gz
    path("versions.yml")                                        , emit: versions


    script:
    """
    # iterate over phist tables
    for table in ${csv_gzs[0]}; do
        zcat \${table} | head -n 2 > ${meta.id}.phist_combined.csv
    done

    for table in ${csv_gzs}; do
        zcat \${table} | tail -n +3 >> ${meta.id}.phist_combined.csv
    done

    gzip ${meta.id}.phist_combined.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        zcat: \$( zcat --version | sed -e "s/zcat (gzip) //g" )
    END_VERSIONS
    """
}
