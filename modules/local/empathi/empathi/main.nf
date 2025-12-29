process EMPATHI_EMPATHI {
    tag "${meta.id}"
    label "process_medium"
    container null
    conda "${moduleDir}/environment.yml"
    publishDir "${params.output_dir}/annotate/empathi"  , mode: 'copy'  , pattern: "${meta.id}.empathi.csv.gz"

    input:
    tuple val(meta) , path(csv_gz)
    path(models)

    output:
    tuple val(meta), path("${meta.id}.empathi.csv.gz")  , emit: csv_gz

    script:
    """
    gunzip -f ${csv_gz}

    empathi \\
        ${csv_gz.getBaseName()} \\
        results \\
        --models_folder ${models} \\
        --only_embeddings \\
        --threads ${task.cpus} \\
        --output_folder ./ \\
        --confidence 0.5

    mv results/predictions_results.csv ${meta.id}.empathi.csv
    gzip ${meta.id}.empathi.csv
    """
}
