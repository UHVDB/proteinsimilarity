process PHYNTENYTRANSFORMER_INSTALLMODELS {
    label 'process_gpu'
    container null
    conda "${moduleDir}/environment.yml"
    storeDir "${params.db_dir}/phynteny/0.1.3"
    tag "Phynteny v0.1.3"
    

    output:
    path("phynteny_db/")    , emit: db

    script:
    """
    # download phynteny models
    install_models -o phynteny_db

    # install pytorch with cuda support
    micromamba install -c conda-forge pytorch=*=cuda* -y
    """
}
