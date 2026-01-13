process PSEUDOFINDER_GETMOD {
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b8a045eec34dae0f3027ab806e8f218a77c5755355480688e500ef644dd5473/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-7e383408cf4a0f05_1?_gl=1*977cpz*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..
    tag "pseudofinder v1.1.0"
    storeDir "${params.db_dir}/pseudofinder_mod/1.1.0"

    input:
    val(url)

    output:
    path("pseudofinder_mod")    , emit: mod

    script:
    """
    git clone ${url} pseudofinder_mod
    """
}
