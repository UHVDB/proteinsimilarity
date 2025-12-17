#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UHVDB/proteinsimilarity
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/UHVDB/proteinsimilarity
----------------------------------------------------------------------------------------
*/


//
// Define modules
//
process VMRTOFASTA {
    label "process_single"
    storeDir "dbs/${task.process.toString().toLowerCase().replace("_", "/")}/${meta.id}"

    input:
    tuple val(meta), path(xlsx)

    output:
    tuple val(meta), path("${meta.id}.fna.gz")                      , emit: fna
    tuple val(meta), path("processed_accessions_b.fa_names.tsv")    , emit: processed_tsv
    tuple val(meta), path("bad_accessions_b.tsv")                   , emit: bad_tsv
    tuple val(meta), path(".command.log")                           , emit: log
    tuple val(meta), path(".command.sh")                            , emit: script

    script:
    """
    # process VMR accessions
    VMR_to_fasta.py \\
        -mode VMR \\
        -ea B \\
        -VMR_file_name ${xlsx} \\
        -v

    # download FNA file using current vmr
    VMR_to_fasta.py \\
        -email ${params.email} \\
        -mode fasta \\
        -ea b \\
        -fasta_dir ./ictv_fastas \\
        -VMR_file_name ${xlsx} \\
        -v

    cat ictv_fastas/*/*.fa > ${meta.id}.fna
    gzip ${meta.id}.fna

    rm -rf fixed_vmr_b.tsv process_accessions_b.tsv ictv_fastas/
    """
}

process SEQKIT_SPLIT2 {
    label 'process_high'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("split_fastas/*") , emit: fnas
    tuple val(meta), path(".command.log")   , emit: log
    tuple val(meta), path(".command.sh")    , emit: script

    script:
    """
    seqkit \\
        split2 \\
            ${fasta} \\
            --threads ${task.cpus} \\
            --by-size ${params.chunk_size} \\
            --out-dir split_fastas
    """
}

process DIAMOND_MAKEDB {
    label "process_super_high"

    input:
    tuple val(meta), path(fna)

    output:
    tuple val(meta), path("${meta.id}.dmnd")                , emit: dmnd
    tuple val(meta), path("${meta.id}.pyrodigalgv.faa.gz")  , emit: faa
    tuple val(meta), path(".command.log")                   , emit: log
    tuple val(meta), path(".command.sh")                    , emit: script

    script:
    """
    # predict genes from FNA
    pyrodigal-gv \\
        -i ${fna} \\
        -a ${meta.id}.pyrodigalgv.faa \\
        --jobs ${task.cpus}

    # create DIAMOND database
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in ${meta.id}.pyrodigalgv.faa \\
        -d ${meta.id}

    gzip ${meta.id}.pyrodigalgv.faa
    """
}


process DIAMOND_BLASTP {
    label 'process_super_high'

    input:
    tuple val(meta) , path(fna)
    tuple val(meta2), path(dmnd)

    output:
    tuple val(meta), path("${meta.id}.diamond_blastp.parquet")  , emit: parquet
    tuple val(meta), path("${meta.id}.pyrodigalgv.faa.gz")      , emit: faa
    tuple val(meta), path(".command.log")                       , emit: log
    tuple val(meta), path(".command.sh")                        , emit: script

    script:
    """
    # predict genes from FNA
    pyrodigal-gv \\
        -i ${fna} \\
        -a ${meta.id}.pyrodigalgv.faa \\
        --jobs ${task.cpus}

    # align genes to DIAMOND reference db
    diamond \\
        blastp \\
        ${params.diamond_args} \\
        --query ${meta.id}.pyrodigalgv.faa \\
        --db ${dmnd} \\
        --threads ${task.cpus} \\
        --outfmt 6 \\
        --out ${meta.id}.diamond_blastp.tsv

    duckdb -c "
        SET memory_limit='${task.memory}'; \\
        SET threads=${task.cpus}; \\
        COPY(select * from read_csv_auto('${meta.id}.diamond_blastp.tsv', delim='\t', header=false, parallel=true)) TO '${meta.id}.diamond_blastp.parquet' WITH (FORMAT 'PARQUET')
    "

    gzip ${meta.id}.pyrodigalgv.faa
    rm -rf ${meta.id}.diamond_blastp.tsv
    """
}

process DIAMOND_SELF {
    label 'process_super_high'

    input:
    tuple val(meta), path(faa)

    output:
    tuple val(meta), path("${meta.id}.diamond_blastp.parquet")  , emit: parquet
    tuple val(meta), path(".command.log")                       , emit: log
    tuple val(meta), path(".command.sh")                        , emit: script

    script:
    """
    # make DIAMOND db for self alignment
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in ${faa} \\
        -d ${meta.id}

    # align genes to DIAMOND self db
    diamond \\
        blastp \\
        --masking none \\
        -k 1000 \\
        -e 1e-3 \\
        --faster \\
        --query ${faa} \\
        --db ${meta.id}.dmnd \\
        --threads ${task.cpus} \\
        --outfmt 6 \\
        --out ${meta.id}.diamond_blastp.tsv

    duckdb -c "
        SET memory_limit='${task.memory}'; \\
        SET threads=${task.cpus}; \\
        COPY(select * from read_csv_auto('${meta.id}.diamond_blastp.tsv', delim='\t', header=false, parallel=true)) TO '${meta.id}.diamond_blastp.parquet' WITH (FORMAT 'PARQUET')
    "

    rm -rf ${meta.id}.diamond_blastp.tsv ${meta.id}.dmnd
    """
}

process SELFSCORE {
    label 'process_single'

    input:
    tuple val(meta), path(parquet)

    output:
    tuple val(meta), path("${meta.id}.selfscore.parquet")   , emit: parquet

    script:
    """
    self_score.py \\
        --input ${parquet} \\
        --output ${meta.id}.selfscore.parquet
    """
}

process NORMSCORE {
    label 'process_high'

    input:
    tuple val(meta), path(self_parquet), path(ref_parquet)

    output:
    tuple val(meta), path("${meta.id}.normscore.tsv.gz")    , emit: tsv

    script:
    """
    norm_score.py \\
        --input ${ref_parquet} \\
        --self_score ${self_parquet} \\
        --min_score ${params.min_score} \\
        --output ${meta.id}.normscore.tsv

    gzip ${meta.id}.normscore.tsv
    """
}

process COMBINESCORES {
    label 'process_single'
    tag "all"
    storeDir file("${params.output}").getParent()

    input:
    tuple val(meta), path(tsvs)

    output:
    tuple val(meta), path("${output}")   , emit: tsv

    script:
    output = file("${params.output}").getName()
    """
    touch ${output}

    # iterate over scores
    for table in ${tsvs}; do
        zcat \${table} >> ${output}
    done
    """
}

//
// Run workflow
//
workflow {

    main:
    // Check if output file already exists
    def output_file = file("${params.output}")
    def vmr_dmnd = params.vmr_dmnd ? file(params.vmr_dmnd).exists() : false

    // Prepare ICTV DIAMOND database
    if (!output_file.exists()) {
        if (!vmr_dmnd) {
            ch_ictv_vmr = channel.fromPath(params.vmr_url).map { xlsx ->
                [ [ id: "${xlsx.getBaseName()}" ], xlsx ]
            }

            VMRTOFASTA(
                ch_ictv_vmr
            )

            DIAMOND_MAKEDB(
                VMRTOFASTA.out.fna
            )
            ch_dmnd_db = DIAMOND_MAKEDB.out.dmnd
        } else {
            ch_dmnd_db = channel.fromPath(params.vmr_dmnd).map { dmnd ->
                [ [ id: "${dmnd.getBaseName()}" ], dmnd ]
            }
        }

        // Split input FNA file
        SEQKIT_SPLIT2(
            channel.fromPath(params.query_fna).map { fna ->
                [ [ id: "${fna.getBaseName()}" ], fna ]
            }
        )

        ch_split_fnas = SEQKIT_SPLIT2.out.fnas
            .map { _meta, fnas -> fnas }
            .flatten()
            .map { fna ->
                [ [ id: fna.getBaseName() ], fna ]
            }

        // Run DIAMOND against ref db
        DIAMOND_BLASTP(
            ch_split_fnas,
            ch_dmnd_db.collect()
        )

        // Run DIAMOND self alignment
        DIAMOND_SELF(
            DIAMOND_BLASTP.out.faa
        )

        // Calculate self score
        SELFSCORE(
            DIAMOND_SELF.out.parquet
        )

        // Calculate normalized bitscore
        NORMSCORE(
            SELFSCORE.out.parquet.combine(DIAMOND_BLASTP.out.parquet, by:0)
        )

        // Combine results
        COMBINESCORES(
            NORMSCORE.out.tsv.map { _meta, tsvs -> [ [ id: 'combined'], tsvs ] }.groupTuple(sort: 'deep')
        )

    } else {
        println "[UHVDB/proteinsimilarity]: Output file [${params.output}] already exists!"
    }


    // Delete intermediate and Nextflow-specific files
    def remove_tmp = params.remove_tmp
    workflow.onComplete {
        if ( (output_file.exists()) && (remove_tmp) ) {
            def work_dir = new File("./work/")
            def nextflow_dir = new File("./.nextflow/")
            def launch_dir = new File(".")
            def tmp_dir = new File("./tmp/")

            work_dir.deleteDir()
            nextflow_dir.deleteDir()
            launch_dir.eachFileRecurse { file ->
                if (file.name ==~ /\.nextflow\.log.*/) {
                    file.delete()
                }
            }
            tmp_dir.deleteDir()
        }
    }
}
