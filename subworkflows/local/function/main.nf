/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// FUNCTIONS
def rmEmptyFastAs(ch_fastas) {
    def ch_nonempty_fastas = ch_fastas
        .filter { _meta, fasta ->
            try {
                file(fasta).countFasta( limit: 1 ) > 0
            } catch (java.util.zip.ZipException e) {
                log.debug "[rmEmptyFastAs]: ${fasta} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                true
            } catch (EOFException) {
                log.debug "[rmEmptyFastAs]: ${fasta} has an EOFException, this is likely an empty gzipped file."
            }
        }
    return ch_nonempty_fastas
}

// MODULES
include { BAKTA_DOWNLOAD                } from '../../../modules/local/bakta/download'
include { BAKTA_GETMOD                  } from '../../../modules/local/bakta/getmod'
include { BAKTA_VIRUS                   } from '../../../modules/local/bakta/virus'
include { CARD_DIAMOND                  } from '../../../modules/local/card/diamond'
include { CARD_DOWNLOAD                 } from '../../../modules/local/card/download'
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
include { UHVDB_CATHEADER               } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_CATNOHEADER             } from '../../../modules/local/uhvdb/catnoheader'
include { UHVDB_CATGFF                  } from '../../../modules/local/uhvdb/catgff'
include { UNIREF50VIRUS                 } from '../../../modules/local/uniref50virus'
include { VFDB_DIAMOND                  } from '../../../modules/local/vfdb/diamond'
include { VFDB_DOWNLOAD                 } from '../../../modules/local/vfdb/download'

//
// Run function workflow
//
workflow FUNCTION {

    take:
    split_virus_fna_gz      // channel: [ [ meta ], virus.split.fna.gz ]
    virus_summary_tsv_gz    // channel: [ [ meta ], virus.summary.tsv.gz ]

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
    // MODULE: Download CARD database
    //
    CARD_DOWNLOAD()

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

    //
    // MODULE: Download VFDB database
    //
    VFDB_DOWNLOAD()

    //-------------------------------------
    // Run annotation tools
    //-------------------------------------

    //
    // MODULE: Split input FNA based on genetic code
    //
    GENETICCODE_SPLIT(
        split_virus_fna_gz,
        virus_summary_tsv_gz
    )
    ch_gcode_split_fna_gz = GENETICCODE_SPLIT.out.fna_gzs
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
        ch_gcode_split_fna_gz,
        BAKTA_DOWNLOAD.out.db.collect(),
        UNIREF50VIRUS.out.faa_gz.collect(),
        BAKTA_GETMOD.out.bakta_mod.collect()
    )

    // //
    // // MODULE: Annotate hypothetical proteins with InterProScan
    // //
    // INTERPROSCAN_INTERPROSCAN(
    //     rmEmptyFastAs(BAKTA_VIRUS.out.hyp_faa_gz),
    //     INTERPROSCAN_DOWNLOAD.out.db.collect()
    // )

    // //
    // // MODULE: Convert FAA to 3Di foldseek database
    // //
    // FOLDSEEK_CREATEDBPROSTT5(
    //     rmEmptyFastAs(BAKTA_VIRUS.out.nohit_faa_gz),
    //     FOLDSEEK_CREATEDB.out.weights.collect()
    // )

    // //
    // // MODULE: Align proteins without UniProt hit to reference structures
    // //
    // FOLDSEEK_EASYSEARCH(
    //     FOLDSEEK_CREATEDBPROSTT5.out.db,
    //     FOLDSEEK_CREATEDB.out.db.collect()
    // )

    // //
    // // MODULE: Run pseudofinder for proteins without UniProt hit
    // //
    // PSEUDOFINDER_ANNOTATE(
    //     BAKTA_VIRUS.out.gbk_gz.combine(FOLDSEEK_EASYSEARCH.out.tsv_gz, by:0),
    //     PSEUDOFINDER_MAKEDB.out.dmnd.collect(),
    //     PSEUDOFINDER_GETMOD.out.mod.collect()
    // )

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

    // //
    // // MODULE: Identify DGRs with DGRscan
    // //
    // DGRSCAN(
    //     split_virus_fna_gz
    // )

    //
    // MODULE: Identify antibiotic resistance genes with CARD DIAMOND
    //
    CARD_DIAMOND(
        BAKTA_VIRUS.out.faa_gz,
        CARD_DOWNLOAD.out.dmnd.collect()
    )

    //
    // MODULE: Identify virulence factors with VFDB DIAMOND
    //
    VFDB_DIAMOND(
        BAKTA_VIRUS.out.faa_gz,
        VFDB_DOWNLOAD.out.dmnd.collect()
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

    ch_catheader_input = (
        BAKTA_VIRUS.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'bakta' ], tsv_gz, 6, 'tsv' ] }
        // .mix(DGRSCAN.out.txt_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'dgrscan' ], tsv_gz, 1, 'tsv' ] })
        .mix(DEFENSEFINDER_RUN.out.genes_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'defensefinder' ], tsv_gz, 1, 'tsv' ] })
        .mix(EMPATHI_EMPATHI.out.csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id:'empathi' ], csv_gz, 1, 'csv' ] })
        .mix(PADLOC_PADLOC.out.csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id:'padloc' ], csv_gz, 1, 'csv' ] })
        .mix(PHAROKKA_PHAROKKA.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'pharokka' ], tsv_gz, 1, 'tsv' ] })
        .mix(PHOLD_COMPARE.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'phold' ], tsv_gz, 1, 'tsv' ] })
        .mix(PHYNTENYTRANSFORMER_PHYNTENYTRANSFORMER.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'phynteny' ], tsv_gz, 1, 'tsv' ] })
    )
    
    ch_catnoheader_input = (
        BAKTA_VIRUS.out.gbk_gz.map { _meta, gbk_gz -> gbk_gz }.collect().map { gbk_gz -> [ [ id:'bakta' ], gbk_gz, 'gbk.gz' ] }
        // .mix(FOLDSEEK_EASYSEARCH.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'foldseek' ], tsv_gz, 'tsv.gz' ] })
        // .mix(INTERPROSCAN_INTERPROSCAN.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'interproscan' ], tsv_gz, 'tsv.gz' ] })
        .mix(CARD_DIAMOND.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'card' ], tsv_gz, 'tsv.gz' ] })
        .mix(VFDB_DIAMOND.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'vfdb' ], tsv_gz, 'tsv.gz' ] })
    )

    // ch_catgff_input = (
    //     PSEUDOFINDER_ANNOTATE.out.gff_gz.map { _meta, gff_gz -> gff_gz }.collect().map { gff_gz -> [ [ id:'pseudofinder' ], gff_gz ] }
    // )

    //
    // MODULE: Combine outputs with a header
    //
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}/annotate/function"
    )

    //
    // MODULE: Combine outputs without a header
    //
    UHVDB_CATNOHEADER(
        ch_catnoheader_input,
        "${params.output_dir}/${params.new_release_id}/annotate/function"
    )

    // //
    // // MODULE: Combine gff outputs
    // //
    // UHVDB_CATGFF(
    //     ch_catgff_input,
    //     "${params.output_dir}/${params.new_release_id}/annotate/function"
    // )

    emit:
    bakta_gbk_gz    = BAKTA_VIRUS.out.gbk_gz // (for referenceanalyze subworkflow)
    bakta_faa_gz    = BAKTA_VIRUS.out.faa_gz // (for proteinsimilarity + aaicluster subworkflows)
    empathi_csv_gz  = EMPATHI_EMPATHI.out.csv_gz // (for lifestyle subworkflow)
    phynteny_tsv_gz = PHYNTENYTRANSFORMER_PHYNTENYTRANSFORMER.out.tsv_gz // (for lifestyle subworkflow)
}

