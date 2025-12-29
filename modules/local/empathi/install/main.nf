process EMPATHI_INSTALL {
    tag "empathi_models"
    label "process_gpu"
    container null
    conda "${moduleDir}/environment.yml"
    storeDir "${params.db_dir}/empathi"

    output:
    path("empathi/models/") , emit: models

    script:
    """
    # install git-lfs
    git lfs install

    # clone empathi repo
    git clone https://huggingface.co/AlexandreBoulay/empathi
    export PATH="empathi/models:\$PATH"

    # install empathi software
    export PIP_CACHE_DIR=${params.db_dir}/.pip-cache
    pip install empathi
    """
}
