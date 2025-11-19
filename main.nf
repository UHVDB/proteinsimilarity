#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CarsonJM/nf-protsim
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/CarsonJM/nf-protsim
----------------------------------------------------------------------------------------
    Overview:
        1. Download latest ICTV VMR (Nextflow)
        2. Download ICTV genomes (process - VMR_to_fasta.py)
        3. Create DIAMOND database of ICTV genomes (process - DIAMOND)
        4. Split query viruses into chunks (process - seqkit)
        5. Align query virus genomes to ICTV database (process - DIAMOND)
        6. Perform self alignment of query genomes (process - DIAMOND)
        7. Calculate self score and normalized protein similarity (process - python)
*/


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEFINE FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
process PROCESS_ACCESSIONS {
    label "process_single"
    // storeDir "tmp/vmr_to_fasta/"

    conda "envs/vmr_to_fasta.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c2/c22b4cc5cf94719862d060cabd555b816d60820fbacc0b1521d1d9ac75b0d01e/data' :
        'community.wave.seqera.io/library/numpy_pandas:cf3ee2b3d6008f1b' }"

    input:
    path(vmr)

    output:
    path("processed_accessions_b.tsv")  , emit: processed_accessions

    script:
    """
    # process VMR accessions
    VMR_to_fasta.py \\
        -mode VMR \\
        -ea B \\
        -VMR_file_name ${vmr} \\
        -v
    """
}

process VMR_TO_FASTA {
    label "process_single"
    // storeDir "tmp/vmr_to_fasta/"

    conda "envs/vmr_to_fasta.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c2/c22b4cc5cf94719862d060cabd555b816d60820fbacc0b1521d1d9ac75b0d01e/data' :
        'community.wave.seqera.io/library/numpy_pandas:cf3ee2b3d6008f1b' }"

    input:
    path(vmr)
    path(processed_acc)

    // output:
    // tuple val(meta), path("host_fastas/")       , emit: host_fastas
    // tuple val(meta), path("download_complete")  , emit: download_complete

    script:
    """
    # download fasta file using current vmr
    VMR_to_fasta.py \\
        -email ${params.email} \\
        -mode fasta \\
        -ea b \\
        -fasta_dir ./ictv_fastas \\
        -VMR_file_name ${vmr} \\
        -v
    """
}

// Run entry workflow
workflow {
    main:
    // Check if output file already exists
    def output_file = file("${params.output}")
    if (!output_file.exists()) {

        // 1. Split input files into chunks of X genomes (Nextflow)
        ch_virus_fasta = channel.fromPath(params.virus_fasta).collect()
        ch_ictv_vmr = channel.fromPath(params.vmr_url)

        // 1. Process VMR accessions (process - VMR_to_fasta.py)
        PROCESS_ACCESSIONS(
            ch_ictv_vmr
        )

        // 2. Download fasta (process - VMR_to_fasta.py)
        VMR_TO_FASTA(
            ch_ictv_vmr,
            PROCESS_ACCESSIONS.out.processed_accessions
        )
    } else {
        println "Output file [${params.output}] already exists! Skipping nf-proteinsimilarity."
    }

    // Delete intermediate and Nextflow-specific files
    workflow.onComplete {
        if (output_file.exists()) {
            def work_dir = new File("./work/")
            def tmp_dir = new File("./tmp/")
            def nextflow_dir = new File("./.nextflow/")
            def launch_dir = new File(".")

            work_dir.deleteDir()
            tmp_dir.deleteDir()
            nextflow_dir.deleteDir()
            launch_dir.eachFileRecurse { file ->
                if (file.name ==~ /\.nextflow\.log.*/) {
                    file.delete()
                }
            }
        }
    }
}