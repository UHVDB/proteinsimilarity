process BAKTA_VIRUS {
    tag "${meta.id}"
    label 'process_high_mem'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2d/2dfb94caa02cda7e8fa885d1cd8190620d1a067c4a5045e84df6cfc2f89b7d12/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ab739ec5f76b6b51_1?_gl=1*2ib32a*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.
    time '24.h'

    input:
    tuple val(meta) , path(fna)
    path(db)
    path(uniref50_virus_db)
    path(bakta_mod)

    output:
    tuple val(meta), path("${meta.id}.gbff.gz")                 , emit: gbk_gz
    tuple val(meta), path("${meta.id}.gff3.gz")                 , emit: gff_gz
    tuple val(meta), path("${meta.id}.tsv.gz")                  , emit: tsv_gz
    tuple val(meta), path("${meta.id}.ffn.gz")                  , emit: ffn_gz
    tuple val(meta), path("${meta.id}.faa.gz")                  , emit: faa_gz
    tuple val(meta), path("${meta.id}.hypotheticals.faa.gz")    , emit: hyp_faa_gz
    tuple val(meta), path("${meta.id}.nohit.faa.gz")            , emit: nohit_faa_gz

    script:
    """
    ### Run pyrodigal-gv
    pyrodigal-gv \\
        -i ${fna} \\
        -c \\
        -g ${meta.g_code} \\
        -f gbk \\
        -o ${meta.id}.pyrodigalgv.gbk \\
        --jobs ${task.cpus}

    ### Run bakta
    bash ${bakta_mod}/bin/bakta \\
        ${fna} \\
        --regions ${meta.id}.pyrodigalgv.gbk \\
        --proteins ${uniref50_virus_db} \\
        --threads ${task.cpus} \\
        --db ${db} \\
        --keep-contig-headers \\
        --translation-table ${meta.g_code} \\
        --skip-ori \\
        --skip-plot \\
        --prefix ${meta.id}

    ### Identify proteins without hits
    extract_nohit_proteins.py \\
        --input_tsv ${meta.id}.tsv \\
        --input_faa ${meta.id}.faa \\
        --name_column="Locus Tag" \\
        --output ${meta.id}.nohit.faa

    sed -i "s/?\\t/pyrodigal-gv\\t/" ${meta.id}.gff3

    ### Compress
    gzip -f ${meta.id}.gbff
    gzip -f ${meta.id}.gff3
    gzip -f ${meta.id}.tsv
    gzip -f ${meta.id}.ffn
    gzip -f ${meta.id}.faa
    gzip -f ${meta.id}.hypotheticals.faa
    gzip -f ${meta.id}.nohit.faa

    ### Cleanup
    rm -rf ${meta.id}.pyrodigalgv.gbk ${meta.id}.embl ${meta.id}.fna \\
        ${meta.id}.hypotheticals.tsv ${meta.id}.inference.tsv ${meta.id}.json \\
        ${meta.id}.log ${meta.id}.txt 
    """
}
