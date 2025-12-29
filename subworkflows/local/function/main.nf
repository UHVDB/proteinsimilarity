/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { BAKTA_DOWNLOAD                } from '../../../modules/local/bakta/download'
include { BAKTA_GETMOD                  } from '../../../modules/local/bakta/getmod'
include { BAKTA_VIRUS                   } from '../../../modules/local/bakta/virus'
include { DEFENSEFINDER_UPDATE          } from '../../../modules/local/defensefinder/update'
include { DEFENSEFINDER_RUN             } from '../../../modules/local/defensefinder/run'
include { DGRSCAN                       } from '../../../modules/local/dgrscan'
include { EMPATHI_INSTALL               } from '../../../modules/local/empathi/install'
include { EMPATHI_EMPATHI               } from '../../../modules/local/empathi/empathi'
include { EMPATHI_ONLYEMBEDDINGS        } from '../../../modules/local/empathi/onlyembeddings'
include { FOLDSEEK_CREATEDB             } from '../../../modules/local/foldseek/createdb'
include { FOLDSEEK_CREATEDBPROSTT5      } from '../../../modules/local/foldseek/createdbprostt5'
include { FOLDSEEK_EASYSEARCH           } from '../../../modules/local/foldseek/easysearch'
include { GENETICCODE_SPLIT             } from '../../../modules/local/geneticcodesplit'
include { INTERPROSCAN_DOWNLOAD         } from '../../../modules/local/interproscan/download'
include { INTERPROSCAN_INTERPROSCAN     } from '../../../modules/local/interproscan/interproscan'
include { PADLOC_UPDATE                 } from '../../../modules/local/padloc/update'
include { PADLOC_PADLOC                 } from '../../../modules/local/padloc/padloc'
include { PHAROKKA_INSTALLDATABASES     } from '../../../modules/local/pharokka/installdatabases'
include { PHAROKKA_PHAROKKA             } from '../../../modules/local/pharokka/pharokka'
include { PHOLD_INSTALL                 } from '../../../modules/local/phold/install'
include { PHOLD_PREDICT                 } from '../../../modules/local/phold/predict'
include { PHOLD_COMPARE                 } from '../../../modules/local/phold/compare'
include { PHYNTENYTRANSFORMER_INSTALLMODELS } from '../../../modules/local/phyntenytransformer/installmodels'
include { PHYNTENYTRANSFORMER_PHYNTENYTRANSFORMER } from '../../../modules/local/phyntenytransformer/phyntenytransformer'
include { PSEUDOFINDER_MAKEDB           } from '../../../modules/local/pseudofinder/makedb'
include { PSEUDOFINDER_GETMOD           } from '../../../modules/local/pseudofinder/getmod'
include { PSEUDOFINDER_ANNOTATE         } from '../../../modules/local/pseudofinder/annotate'
include { SEQKIT_SPLIT2                 } from '../../../modules/local/seqkit/split2'
include { UNIREF50VIRUS                 } from '../../../modules/local/uniref50virus'

//
// Run function workflow
//
workflow FUNCTION {

    take:
    hq_virus_fna_gz         // channel: [ [ meta ], fna.gz ]
    virus_summary_tsv_gz     // channel: [ [ meta ], genomad_virus_summary.tsv.gz ]

    main:

    //-------------------------------------
    // Download databases
    //-------------------------------------
    //

    // MODULE: Download Bakta database
    //
    BAKTA_DOWNLOAD()

    //
    // MODULE: Download modified Bakta
    //
    BAKTA_GETMOD(params.bakta_mod_url)

    //
    // MODULE: Download Defensefinder database
    //
    DEFENSEFINDER_UPDATE()

    //
    // MODULE: Create foldseek database from PDB file(s)
    //
    ch_virus_structures = channel.fromPath( params.virus_structures ).collect()
    FOLDSEEK_CREATEDB(ch_virus_structures)

    //
    // MODULE: Download InterProscan database
    //
    INTERPROSCAN_DOWNLOAD()

    //
    // MODULE: Download Empathi models
    //
    EMPATHI_INSTALL()

    //
    // MODULE: Download PADLOC database
    //
    PADLOC_UPDATE()

    //
    // MODULE: Download Pharokka database
    //
    PHAROKKA_INSTALLDATABASES()

    //
    // MODULE: Download Phold database
    //
    PHOLD_INSTALL()

    //
    // MODULE: Download phynteny models
    //
    PHYNTENYTRANSFORMER_INSTALLMODELS()

    //
    // MODULE: Download pseudofinder reference sequences
    //
    ch_pseudofinder_faa = channel.fromPath(params.pseudofinder_ref_fasta)
    PSEUDOFINDER_MAKEDB(ch_pseudofinder_faa)

    //
    // MODULE: Download modified pseudofinder
    //
    PSEUDOFINDER_GETMOD(params.pseudofinder_mod_url)

    //
    // MODULE: Download UniRef50 virus sequences
    //
    UNIREF50VIRUS()

    //-------------------------------------
    // Run annotation tools
    //-------------------------------------

    //
    // MODULE: Split input FNA based on genetic code
    //
    GENETICCODE_SPLIT(
        hq_virus_fna_gz.combine(virus_summary_tsv_gz, by:0)
    )

    ch_gcode_split_fna_zst = GENETICCODE_SPLIT.out.fna_zst
        .map { _meta, fna_zst -> fna_zst }
        .flatten()
        .map { fna_zst ->
            [ [ id: fna_zst.getBaseName() ], fna_zst ]
        }

    //
    // MODULE: Split input FNA into chunks
    //
    SEQKIT_SPLIT2(
        ch_gcode_split_fna_zst,
        params.function_chunk_size
    )

    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            def g_code = fna_gz.getBaseName().toString() =~ /gcode(\d+)/
            [ [ id: fna_gz.getBaseName(), g_code: g_code[0][1] ], fna_gz ]
        }

    //
    // MODULE: Predict features and annotate with BAKTA
    //
    BAKTA_VIRUS(
        ch_split_fna_gz,
        BAKTA_DOWNLOAD.out.db.collect(),
        UNIREF50VIRUS.out.faa_gz.collect(),
        BAKTA_GETMOD.out.bakta_mod.collect()
    )

    //
    // MODULE: Annotate hypothetical proteins with InterProScan
    //
    INTERPROSCAN_INTERPROSCAN(
        BAKTA_VIRUS.out.hyp_faa_gz,
        INTERPROSCAN_DOWNLOAD.out.db.collect()
    )

    //
    // MODULE: Convert FAA to 3Di foldseek database
    //
    FOLDSEEK_CREATEDBPROSTT5(
        BAKTA_VIRUS.out.nohit_faa_gz,
        FOLDSEEK_CREATEDB.out.weights.collect()
    )

    //
    // MODULE: Align proteins without UniProt hit to reference structures
    //
    FOLDSEEK_EASYSEARCH(
        FOLDSEEK_CREATEDBPROSTT5.out.db,
        FOLDSEEK_CREATEDB.out.db.collect()
    )

    //
    // MODULE: Run pseudofinder for proteins without UniProt hit
    //
    PSEUDOFINDER_ANNOTATE(
        BAKTA_VIRUS.out.gbk_gz.combine(FOLDSEEK_EASYSEARCH.out.m8_gz, by:0),
        PSEUDOFINDER_MAKEDB.out.dmnd.collect(),
        PSEUDOFINDER_GETMOD.out.mod.collect()
    )

    //
    // MODULE: Identify defense systems with DefenseFinder
    //
    DEFENSEFINDER_RUN(
        BAKTA_VIRUS.out.faa_gz,
        DEFENSEFINDER_UPDATE.out.db.collect()
    )

    //
    // MODULE: Identify defense systems with PADLOC
    //
    PADLOC_PADLOC(
        BAKTA_VIRUS.out.faa_gz.combine(BAKTA_VIRUS.out.gff_gz, by:0),
        PADLOC_UPDATE.out.db
    )

    //
    // MODULE: Identify DGRs with DGRscan
    //
    DGRSCAN(
        ch_split_fna_gz
    )

    //
    // MODULE: Assign PHROGs with Pharokka
    //
    PHAROKKA_PHAROKKA(
        BAKTA_VIRUS.out.gbk_gz,
        PHAROKKA_INSTALLDATABASES.out.db.collect()
    )

    //
    // MODULE: Convert proteins to 3Di seqs
    PHOLD_PREDICT(
        PHAROKKA_PHAROKKA.out.gbk_gz,
        PHOLD_INSTALL.out.db.collect()
    )

    //
    // MODULE: Compare phold outputs to reference phage structures
    //
    PHOLD_COMPARE(
        PHAROKKA_PHAROKKA.out.gbk_gz.combine(PHOLD_PREDICT.out.predict, by:0),
        PHOLD_INSTALL.out.db.collect()
    )

    //
    // MODULE: Assign additional phrog categories via synteny
    //
    PHYNTENYTRANSFORMER_PHYNTENYTRANSFORMER(
        PHOLD_COMPARE.out.gbk_gz,
        PHYNTENYTRANSFORMER_INSTALLMODELS.out.db.collect()
    )

    //
    // MODULE: Calculate embeddings using empathi
    //
    EMPATHI_ONLYEMBEDDINGS(
        BAKTA_VIRUS.out.faa_gz,
        EMPATHI_INSTALL.out.models.collect()
    )

    //
    // MODULE: Annotate proteins from embeddings
    //
    EMPATHI_EMPATHI(
        EMPATHI_ONLYEMBEDDINGS.out.csv_gz,
        EMPATHI_INSTALL.out.models.collect()
    )

    //
    // MODULE: Create combined results files
    //
    // Bakta TSV + foldseek + pseudofinder + interproscan (for UniProt/InterPro hits)
    // pharokka + phold + phynteny (for lifestyle subworkflow)
    // defensefinder + padloc + dbAPIs (for defense systems)

    emit:
    bakta_gbk_gz    = BAKTA_VIRUS.out.gbk_gz // (for instrain profile)
    empathi_csv_gz   = EMPATHI_EMPATHI.out.csv_gz // (for lifestyle subworkflow)
    // pharokka + phold + phynteny (for lifestyle subworkflow)
}

