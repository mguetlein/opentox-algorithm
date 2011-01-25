ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_NO_AROMATIC'] = 'true'
ENV['FMINER_PVALUES'] = 'true'

@@bbrc = Bbrc::Bbrc.new 
@@last = Last::Last.new 

# Get list of fminer algorithms
#
# @return [text/uri-list] URIs of fminer algorithms
get '/fminer/?' do
  response['Content-Type'] = 'text/uri-list'
  [ url_for('/fminer/bbrc', :full), url_for('/fminer/last', :full) ].join("\n") + "\n"
end

# Get RDF/XML representation of fminer bbrc algorithm
# @return [application/rdf+xml] OWL-DL representation of fminer bbrc algorithm
get "/fminer/bbrc/?" do
	response['Content-Type'] = 'application/rdf+xml'
  algorithm = OpenTox::Algorithm::Generic.new(url_for('/fminer/bbrc',:full))
  algorithm.metadata = {
    DC.title => 'fminer backbone refinement class representatives',
    DC.creator => "andreas@maunz.de, helma@in-silico.ch",
    DC.contributor => "vorgrimmlerdavid@gmx.de",
    OT.isA => OTA.PatternMiningSupervised,
    OT.parameters => [
    { DC.description => "Dataset URI", OT.paramScope => "mandatory", DC.title => "dataset_uri" },
    { DC.description => "Feature URI for dependent variable", OT.paramScope => "mandatory", DC.title => "prediction_feature" },
    { DC.description => "Minimum frequency", OT.paramScope => "optional", DC.title => "minfreq" },
    { DC.description => "Feature type, can be 'paths' or 'trees'", OT.paramScope => "optional", DC.title => "feature_type" },
    { DC.description => "BBRC classes, pass 'false' to switch off mining for BBRC representatives.", OT.paramScope => "optional", DC.title => "backbone" },
    { DC.description => "Significance threshold (between 0 and 1)", OT.paramScope => "optional", DC.title => "min_chisq_significance" },
    ]
  }
  algorithm.to_rdfxml
end

# Get RDF/XML representation of fminer last algorithm
# @return [application/rdf+xml] OWL-DL representation of fminer last algorithm
get "/fminer/last/?" do
  algorithm = OpenTox::Algorithm::Generic.new(url_for('/fminer/last',:full))
  algorithm.metadata = {
    DC.title => 'fminer latent structure class representatives',
    DC.creator => "andreas@maunz.de, helma@in-silico.ch",
    DC.contributor => "vorgrimmlerdavid@gmx.de",
    OT.isA => OTA.PatternMiningSupervised,
    OT.parameters => [
    { DC.description => "Dataset URI", OT.paramScope => "mandatory", DC.title => "dataset_uri" },
    { DC.description => "Feature URI for dependent variable", OT.paramScope => "mandatory", DC.title => "prediction_feature" },
    { DC.description => "Minimum frequency", OT.paramScope => "optional", DC.title => "minfreq" },
    { DC.description => "Feature type, can be 'paths' or 'trees'", OT.paramScope => "optional", DC.title => "feature_type" },
    { DC.description => "Maximum number of hops", OT.paramScope => "optional", DC.title => "hops" },
    ]
  }
  algorithm.to_rdfxml
end

# Run bbrc algorithm on dataset
#
# @param [String] dataset_uri URI of the training dataset
# @param [String] prediction_feature URI of the prediction feature (i.e. dependent variable)
# @param [optional] parameters BBRC parameters, accepted parameters are
#   - minfreq  Minimum frequency (default 5)
#   - feature_type Feature type, can be 'paths' or 'trees' (default "trees")
#   - backbone BBRC classes, pass 'false' to switch off mining for BBRC representatives. (default "true")
#   - min_chisq_significance Significance threshold (between 0 and 1)
# @return [text/uri-list] Task URI
post '/fminer/bbrc/?' do 

    # TODO: is this thread safe??
    #@@bbrc = Bbrc::Bbrc.new 
    minfreq = 5 unless minfreq = params[:min_frequency]
    @@bbrc.SetMinfreq(minfreq)
    @@bbrc.SetType(1) if params[:feature_type] == "paths"
    @@bbrc.SetBackbone(params[:backbone]) if params[:backbone]
    @@bbrc.SetChisqSig(params[:min_chisq_significance]) if params[:min_chisq_significance]
    @@bbrc.SetConsoleOut(false)

    halt 404, "Please submit a dataset_uri." unless params[:dataset_uri] and  !params[:dataset_uri].nil?
    halt 404, "Please submit a prediction_feature." unless params[:prediction_feature] and  !params[:prediction_feature].nil?
    prediction_feature = params[:prediction_feature]

    training_dataset = OpenTox::Dataset.find "#{params[:dataset_uri]}", @subjectid
    halt 404, "No feature #{params[:prediction_feature]} in dataset #{params[:dataset_uri]}" unless training_dataset.features and training_dataset.features.include?(params[:prediction_feature])

    task = OpenTox::Task.create("Mining BBRC features", url_for('/fminer',:full)) do 

      feature_dataset = OpenTox::Dataset.new(nil, @subjectid)
      feature_dataset.add_metadata({
        DC.title => "BBRC representatives for " + training_dataset.metadata[DC.title].to_s,
        DC.creator => url_for('/fminer/bbrc',:full),
        OT.hasSource => url_for('/fminer/bbrc', :full),
        OT.parameters => [
          { DC.title => "dataset_uri", OT.paramValue => params[:dataset_uri] },
          { DC.title => "prediction_feature", OT.paramValue => params[:prediction_feature] }
        ]
      })
      feature_dataset.save(@subjectid)

      id = 1 # fminer start id is not 0
      compounds = []
      nr_active=0
      nr_inactive=0
      all_activities = Hash.new# DV: for effect calculation in regression part

      @@bbrc.Reset
      training_dataset.data_entries.each do |compound,entry|
        begin
          smiles = OpenTox::Compound.new(compound.to_s).to_smiles
        rescue
          LOGGER.warn "No resource for #{compound.to_s}"
          next
        end
        if smiles == '' or smiles.nil?
          LOGGER.warn "Cannot find smiles for #{compound.to_s}."
          next
        end
        entry.each do |feature,values|
          values.each do |value|
            if value.nil? 
              LOGGER.warn "No #{feature} activiity for #{compound.to_s}."
            else
              case value.to_s
              when "true"
                nr_active += 1
                activity = 1
              when "false"
                nr_inactive += 1
                activity = 0
              else
                activity = value.to_f
                @@bbrc.SetRegression(true)
              end
              begin
                @@bbrc.AddCompound(smiles,id)
                @@bbrc.AddActivity(activity, id)
                all_activities[id]=activity # DV: insert global information
                compounds[id] = compound
                id += 1
              rescue
                LOGGER.warn "Could not add " + smiles + "\t" + value.to_s + " to fminer"
              end
            end
          end
        end
      end

      g_array=all_activities.values # DV: calculation of global median for effect calculation
      g_median=OpenTox::Algorithm.median(g_array)
      
      raise "No compounds in dataset #{training_dataset.uri}" if compounds.size==0

      features = Set.new
      # run @@bbrc
      (0 .. @@bbrc.GetNoRootNodes()-1).each do |j|

        results = @@bbrc.MineRoot(j)
        results.each do |result|
          f = YAML.load(result)[0]
          smarts = f[0]
          p_value = f[1]

          if (!@@bbrc.GetRegression) 
            ids = f[2] + f[3]
            if f[2].size.to_f/ids.size > nr_active.to_f/(nr_active+nr_inactive)
              effect = 'activating'
            else
              effect = 'deactivating'
            end
          else #regression part
            ids = f[2]
            # DV: effect calculation
            f_arr=Array.new
            f[2].each do |id|
              f_arr.push(all_activities[id]) 
            end 
            f_median=OpenTox::Algorithm.median(f_arr)
            if g_median >= f_median 
              effect = 'activating'
            else
              effect = 'deactivating'
            end
          end

          feature_uri = File.join feature_dataset.uri,"feature","bbrc", features.size.to_s
          unless features.include? smarts
            features << smarts
            metadata = {
              OT.hasSource => url_for('/fminer/bbrc', :full),
              OT.isA => OT.Substructure,
              OT.smarts => smarts,
              OT.pValue => p_value.to_f,
              OT.effect => effect,
              OT.parameters => [
                { DC.title => "dataset_uri", OT.paramValue => params[:dataset_uri] },
                { DC.title => "prediction_feature", OT.paramValue => params[:prediction_feature] }
              ]
            }
            feature_dataset.add_feature feature_uri, metadata
            #feature_dataset.add_feature_parameters feature_uri, feature_dataset.parameters
          end
          ids.each { |id| feature_dataset.add(compounds[id], feature_uri, true)}
        end
      end
      feature_dataset.save(@subjectid) 
      feature_dataset.uri
    end
    response['Content-Type'] = 'text/uri-list'
    halt 503,task.uri+"\n" if task.status == "Cancelled"
    halt 202,task.uri.to_s+"\n"
  end
#end

# Run last algorithm on a dataset
#
# @param [String] dataset_uri URI of the training dataset
# @param [String] prediction_feature URI of the prediction feature (i.e. dependent variable)
# @param [optional] parameters LAST parameters, accepted parameters are
#   - minfreq  Minimum frequency (default 5)
#   - feature_type Feature type, can be 'paths' or 'trees' (default "trees")
#   - hops Maximum number of hops
# @return [text/uri-list] Task URI
post '/fminer/last/?' do
  #@@last = Last::Last.new 
  minfreq = 5 unless minfreq = params[:min_frequency]
  @@last.SetMinfreq(minfreq)
  @@last.SetType(1) if params[:feature_type] == "paths"
  @@last.SetMaxHops(params[:hops]) if params[:hops]
  @@last.SetConsoleOut(false)

  halt 404, "Please submit a dataset_uri." unless params[:dataset_uri] and  !params[:dataset_uri].nil?
  halt 404, "Please submit a prediction_feature." unless params[:prediction_feature] and  !params[:prediction_feature].nil?
  prediction_feature = params[:prediction_feature]

  training_dataset = OpenTox::Dataset.new "#{params[:dataset_uri]}", @subjectid
  
  training_dataset.load_all(@subjectid)
  halt 404, "No feature #{params[:prediction_feature]} in dataset #{params[:dataset_uri]}" unless training_dataset.features and training_dataset.features.include?(params[:prediction_feature])

  task = OpenTox::Task.create("Mining LAST features", url_for('/fminer',:full)) do 

    feature_dataset = OpenTox::Dataset.new
    feature_dataset.add_metadata({
      DC.title => "LAST representatives for " + training_dataset.metadata[DC.title].to_s,
      DC.creator => url_for('/fminer/last',:full),
      OT.hasSource => url_for('/fminer/last', :full),
      OT.parameters => [
        { DC.title => "dataset_uri", OT.paramValue => params[:dataset_uri] },
        { DC.title => "prediction_feature", OT.paramValue => params[:prediction_feature] }
      ]
    })
    feature_dataset.save(@subjectid)

    id = 1 # fminer start id is not 0
    compounds = []
    smi = [] # AM LAST: needed for matching the patterns back
    nr_active=0
    nr_inactive=0
    all_activities = Hash.new# DV: for effect calculation in regression part

    @@last.Reset
    training_dataset.data_entries.each do |compound,entry|
      begin
        smiles = OpenTox::Compound.new(compound.to_s).to_smiles
      rescue
        LOGGER.warn "No resource for #{compound.to_s}"
        next
      end
      if smiles == '' or smiles.nil?
        LOGGER.warn "Cannot find smiles for #{compound.to_s}."
        next
      end
      entry.each do |feature,values|
        values.each do |value|
          if value.nil? 
            LOGGER.warn "No #{feature} activiity for #{compound.to_s}."
          else
            case value.to_s
            when "true"
              nr_active += 1
              activity = 1
            when "false"
              nr_inactive += 1
              activity = 0
            else
              activity = value.to_f
              @@last.SetRegression(true)
            end
            begin
              @@last.AddCompound(smiles,id)
              @@last.AddActivity(activity, id)
              all_activities[id]=activity # DV: insert global information
              compounds[id] = compound
              smi[id] = smiles # AM LAST: changed this to store SMILES.
              id += 1
            rescue
              LOGGER.warn "Could not add " + smiles + "\t" + value.to_s + " to fminer"
            end
          end
        end
      end
    end

    g_array=all_activities.values # DV: calculation of global median for effect calculation
    g_median=OpenTox::Algorithm.median(g_array)
    
    raise "No compounds in dataset #{training_dataset.uri}" if compounds.size==0

    # run @@last
    features = Set.new
    xml = ""

    (0 .. @@last.GetNoRootNodes()-1).each do |j|
      results = @@last.MineRoot(j)
      results.each do |result|
        xml << result
      end
    end

    lu = LU.new                             # AM LAST: uses last-utils here
    dom=lu.read(xml)                        # AM LAST: parse GraphML (needs hpricot, @ch: to be included in wrapper!)
    smarts=lu.smarts_rb(dom,'msa')          # AM LAST: converts patterns to LAST-SMARTS using msa variant (see last-pm.maunz.de)
    instances=lu.match_rb(smi,smarts)       # AM LAST: creates instantiations
    instances.each do |smarts, ids|
      feat_hash = Hash[*(all_activities.select { |k,v| ids.include?(k) }.flatten)] # AM LAST: get activities of feature occurrences; see http://www.softiesonrails.com/2007/9/18/ruby-201-weird-hash-syntax
      @@last.GetRegression() ? p_value = @@last.KSTest(all_activities.values, feat_hash.values).to_f : p_value = @@last.ChisqTest(all_activities.values, feat_hash.values).to_f # AM LAST: use internal function for test


      effect = (p_value > 0) ? "activating" : "deactivating"
      feature_uri = File.join feature_dataset.uri,"feature","last", features.size.to_s
      unless features.include? smarts
        features << smarts
        metadata = {
          OT.isA => OT.Substructure,
          OT.hasSource => feature_dataset.uri,
          OT.smarts => smarts,
          OT.pValue => p_value.to_f,
          OT.effect => effect,
          OT.parameters => [
            { DC.title => "dataset_uri", OT.paramValue => params[:dataset_uri] },
            { DC.title => "prediction_feature", OT.paramValue => params[:prediction_feature] }
          ]
        } 
        feature_dataset.add_feature feature_uri, metadata
      end
      ids.each { |id| feature_dataset.add(compounds[id], feature_uri, true)}
    end
    feature_dataset.save(@subjectid) 
    feature_dataset.uri
  end
  response['Content-Type'] = 'text/uri-list'
  halt 503,task.uri+"\n" if task.status == "Cancelled"
  halt 202,task.uri.to_s+"\n"
end
