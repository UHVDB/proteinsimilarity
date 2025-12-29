process ICTV_VMRTOFASTA {
    tag "${meta.id}"
    label "process_single"
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/75/75e65833e6c52a8d39641b47ff4f6752284b3fc1811bc053ee3835a753850499/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-cb9ca519a948519d_1?_gl=1*786jci*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), path(xlsx)

    output:
    tuple val(meta), path("${meta.id}.fna.gz")                      , emit: fna_gz
    tuple val(meta), path("processed_accessions_b.fa_names.tsv")    , emit: processed_tsv
    tuple val(meta), path("bad_accessions_b.tsv")                   , emit: bad_tsv
    path("versions.yml")                                            , emit: versions

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$( python --version | sed -e "s/Python //g" )
        biopython: \$(python -c "import Bio; print(Bio.__version__)")
        pandas: \$(python -c "import pandas; print(pandas.__version__)")
        numpy: \$(python -c "import numpy; print(numpy.__version__)")
        openpyxl: \$(python -c "import openpyxl; print(openpyxl.__version__)")
        psutil: \$(python -c "import psutil; print(psutil.__version__)")
    END_VERSIONS
    """
}
