process PHOLD_INSTALL {
    tag "phold_db"
    label 'process_gpu'
    conda "${moduleDir}/environment.yml"
    container null
    storeDir "${params.db_dir}/phold"

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
