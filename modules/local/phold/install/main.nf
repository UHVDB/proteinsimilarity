process PHOLD_INSTALL {
    label 'process_gpu'
    conda "${moduleDir}/environment.yml"
    container null
    storeDir "${params.db_dir}/phold/1.2.0"
    tag "Phold v1.2.0"

    output:
    path("phold_db/")       , emit: db

    script:
    """
    # download phold database
    phold install \\
        -d phold_db \\
        -t ${task.cpus}

    # install pytorch with cuda support
    micromamba install -c conda-forge pytorch=*=cuda* -y
    """
}
