OBMOL_METHODS = {
  "NumAtoms" =>       "Number of atoms",
  "NumBonds" =>       "Number of bonds",
  "NumHvyAtoms" =>    "Number of heavy atoms",
  "NumResidues" =>    "Number of residues",
  "NumRotors" =>      "Number of rotatable bonds",
  "GetEnergy" =>      "Heat of formation for this molecule (in kcal/mol)",
  "GetMolWt" =>       "Standard molar mass given by IUPAC atomic masses (amu)",
  "GetExactMass" =>   "Mass given by isotopes (or most abundant isotope, if not specified)",
  "GetTotalCharge" => "Total charge",
}

OBDESCRIPTOR_METHODS = { 
  "HBA1" =>           "Number of hydrogen bond acceptors 1 (JoelLib)",
  "HBA2" =>           "Number of hydrogen bond acceptors 2 (JoelLib)",
  "HBD" =>            "Number of hydrogen bond donors (JoelLib)",
  "L5" =>             "Lipinski rule of five",
  "logP" =>           "Octanol/water partition coefficient",
  "MR" =>             "Molar refractivity",
  "MW" =>             "Molecular weight",
  "nF" =>             "Number of fluorine atoms",
  "nHal" =>           "Number of halogen atoms",
  "spinMult" =>       "Total spin multiplicity",
  "TPSA" =>           "Topological polar surface area",
}

# Get a list of OpenBabel algorithms
# @return [text/uri-list] URIs of OpenBabel algorithms
get '/openbabel' do
  algorithms = OBMOL_METHODS.collect{|name,description| url_for("/openbabel/#{name}",:full)}
  algorithms << OBDESCRIPTOR_METHODS.collect{|name,description| url_for("/openbabel/#{name}",:full)}
  response['Content-Type'] = 'text/uri-list'
  algorithms.join("\n")
end

# Get RDF/XML representation of OpenBabel algorithm
# @return [application/rdf+xml] OWL-DL representation of OpenBabel algorithm
get '/openbabel/:property' do
  description = OBMOL_METHODS[params[:property]] if OBMOL_METHODS.include? params[:property]
  description = OBDESCRIPTOR_METHODS[params[:property]] if OBDESCRIPTOR_METHODS.include? params[:property]
  if description
    algorithm = OpenTox::Algorithm::Generic.new(url_for("/openbabel/#{params[:property]}",:full))
    algorithm.metadata = {
      DC.title => params[:property],
      DC.creator => "helma@in-silico.ch",
      DC.description => description,
      OT.isA => OTA.DescriptorCalculation,
    }
    response['Content-Type'] = 'application/rdf+xml'
    algorithm.to_rdfxml
  else
    halt 404, "Unknown OpenBabel descriptor #{params[:property]}."
  end
end

# Calculate OpenBabel descriptors
# Supports the following OpenBabel methods (see OpenBabel API http://openbabel.org/api/2.2.0/)
#   - NumAtoms       Number of atoms
#   - NumBonds       Number of bonds
#   - NumHvyAtoms    Number of heavy atoms
#   - NumResidues    Number of residues
#   - NumRotors      Number of rotatable bonds
#   - GetEnergy      Heat of formation for this molecule (in kcal/mol)
#   - GetMolWt       Standard molar mass given by IUPAC atomic masses (amu)
#   - GetExactMass   Mass given by isotopes (or most abundant isotope, if not specified)
#   - GetTotalCharge Total charge
#   - HBA1           Number of hydrogen bond acceptors 1 (JoelLib)
#   - HBA2           Number of hydrogen bond acceptors 2 (JoelLib)
#   - HBD            Number of hydrogen bond donors (JoelLib)
#   - L5             Lipinski rule of five
#   - logP           Octanol/water partition coefficient
#   - MR             Molar refractivity
#   - MW             Molecular weight
#   - nF             Number of fluorine atoms
#   - nHal           Number of halogen atoms
#   - spinMult       Total spin multiplicity
#   - TPSA           Topological polar surface area
# @param [String] compound_uri Compound URI
# @return [String] descriptor value
post '/openbabel/:property' do
	obconversion = OpenBabel::OBConversion.new
	obmol = OpenBabel::OBMol.new
  compound = OpenTox::Compound.new params[:compound_uri]
	obconversion.set_in_and_out_formats 'inchi', 'can'
  obconversion.read_string obmol, compound.to_inchi
  if OBMOL_METHODS.keys.include? params[:property]
    eval("obmol.#{params[:property].underscore}").to_s
  elsif OBDESCRIPTOR_METHODS.keys.include? params[:property]
    descriptor = OpenBabel::OBDescriptor.find_type(params[:property])
    descriptor.predict(obmol).to_s
  else
    halt 404, "Cannot calculate property #{params[:property]} with OpenBabel"
  end
end

# Calculate all OpenBabel descriptors for a dataset
# @param [String] dataset_uri Dataset URI
# @return [text/uri-list] Task URI
post '/openbabel' do
  task = OpenTox::Task.create("Calculating OpenBabel descriptors for #{params[:dataset_uri]}", url_for('/openbabel',:full)) do 

    dataset = OpenTox::Dataset.find(params[:dataset_uri])
    result_dataset = OpenTox::Dataset.create
    result_dataset.add_metadata({
      DC.title => "OpenBabel descriptors for " + dataset.metadata[DC.title].to_s,
      DC.creator => url_for('/openbabel',:full),
      OT.hasSource => url_for('/openbabel', :full),
      OT.parameters => [
        { DC.title => "dataset_uri", OT.paramValue => params[:dataset_uri] },
      ]
    })

    obconversion = OpenBabel::OBConversion.new
    obmol = OpenBabel::OBMol.new
    obconversion.set_in_and_out_formats 'inchi', 'can'

    OBMOL_METHODS.merge(OBDESCRIPTOR_METHODS).each do |name,description|
      feature_uri = File.join result_dataset.uri, "feature", "openbabel", name
      metadata = {
        OT.hasSource => url_for("/openbabel/#{name}", :full),
        DC.description => description,
        DC.title => name,
      }
      result_dataset.add_feature feature_uri, metadata
    end

    dataset.compounds.each do |compound_uri|
      compound = OpenTox::Compound.new(compound_uri)
      obconversion.read_string obmol, compound.to_inchi
      #result_dataset.add_compound compound_uri
      OBMOL_METHODS.keys.each do |name|
        feature_uri = File.join result_dataset.uri, "feature", "openbabel", name
        value = eval("obmol.#{name.underscore}").to_f
        result_dataset.add compound_uri, feature_uri, value
      end
      OBDESCRIPTOR_METHODS.keys.each do |name|
        feature_uri = File.join result_dataset.uri, "feature", "openbabel", name
        value = OpenBabel::OBDescriptor.find_type(params[:property]).predict(obmol).to_f
        result_dataset.add compound_uri, feature_uri, value
      end
    end
    result_dataset.save
    result_dataset.uri
  end
  response['Content-Type'] = 'text/uri-list'
  halt 503,task.uri+"\n" if task.status == "Cancelled"
  halt 202,task.uri.to_s+"\n"
end
