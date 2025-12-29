process EMPATHI_ONLYEMBEDDINGS {
    tag "${meta.id}"
    label "process_gpu"
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(faa)
    path(models)

    output:
    tuple val(meta), path("${meta.id}.embeddings.csv.gz")   , emit: csv_gz

    script:
    """
    export HF_DATASETS_CACHE=${params.db_dir}/.huggingface-cache

    gunzip -f ${faa}

    empathi \\
        ${faa.getBaseName()} \\
        ${meta.id} \\
        --models_folder ${models} \\
        --only_embeddings \\
        --threads ${task.cpus} \\
        --output_folder ./ \\
        --confidence 0.5

    mv *.csv ${meta.id}.embeddings.csv
    gzip ${meta.id}.embeddings.csv
    """
}
