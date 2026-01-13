process VFDB_DOWNLOAD {
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e8/e8cd0c84fc74d2b010f1cf3061e9b1b1ffb1415522a4dbff42b3a93150461b3a/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-b7c8dc0d49f17b63_1?_gl=1*1sesm3q*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${params.db_dir}/vfdb/${new java.util.Date().format('yyyy_MM')}"
    tag "VFDB ${new java.util.Date().format('yyyy_MM')}"

    output:
    path("VFDB.dmnd") , emit: dmnd

    script:
    """
    ### Download VFDB proteins
    wget https://www.mgc.ac.cn/VFs/Down/VFDB_setB_pro.fas.gz

    ### Create DIAMOND database
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in VFDB_setB_pro.fas.gz \\
        -d VFDB

    ### Cleanup
    rm -rf VFDB_setB_pro.fas.gz
    """
}
