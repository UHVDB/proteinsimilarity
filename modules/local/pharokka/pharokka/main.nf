process PHAROKKA_PHAROKKA {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e8fd5a881f4f4dd544da48510ca945aa398342fd1439548cea09176d4b47c25/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-4ed8eb0e60aaf382_1?_gl=1*gojbf9*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.

    input:
    tuple val(meta) , path(gbk)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.pharokka.gbk.gz") , emit: gbk_gz
    tuple val(meta), path("${meta.id}.pharokka.tsv.gz") , emit: tsv_gz

    script:
    """
    gunzip -f ${gbk}

    # run pharokka on all fasta files
    pharokka.py \\
        --infile ${gbk.getBaseName()} \\
        --genbank \\
        --outdir pharokka \\
        --database ${db} \\
        --thread ${task.cpus} \\
        --prefix ${meta.id} \\
        --gene_predictor prodigal-gv \\
        --meta \\
        --fast \\
        --skip_extra_annotations \\
        --skip_mash \\
        --custom_hmm ${projectDir}/assets/hmms/dbAPIS.hmm.h3m

    rm -rf ${gbk.getBaseName()}

    # move desired output files to appropriate location
    mv pharokka/*_cds_final_merged_output.tsv ${meta.id}.pharokka.tsv
    mv pharokka/*.gbk ./${meta.id}.pharokka.gbk

    gzip ${meta.id}.pharokka.tsv
    gzip ${meta.id}.pharokka.gbk

    # clean up intermediate files
    rm -rf ${gbk.getBaseName()} pharokka/prodigal-gv* pharokka/terL* pharokka/*.tbl \\
        pharokka/*.gff pharokka/*.gbk pharokka/*_cds_functions.tsv pharokka/single_faas/ \\
        pharokka/single_fastas/ pharokka/single_gffs/
    """
}
