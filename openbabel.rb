# Calculate OpenBabel descriptors
# Supports the following OpenBabel methods (see OpenBabel API http://openbabel.org/api/2.2.0/)
#   - NumAtoms       Number of atoms
#   - NumBonds       Number of bonds
#   - NumHvyAtoms    Number of heavy atoms
#   - NumResidues    Number of residues
#   - NumRotors      Number of rotatable bonds
#   - GetFormula     Stochoimetric formula 
#   - GetEnergy      Heat of formation for this molecule (in kcal/mol)
#   - GetMolWt       Standard molar mass given by IUPAC atomic masses (amu)
#   - GetExactMass   Mass given by isotopes (or most abundant isotope, if not specified)
#   - GetTotalCharge Total charge
#   - HBA1           Number of Hydrogen Bond Acceptors 1 (JoelLib)
#   - HBA2           Number of Hydrogen Bond Acceptors 2 (JoelLib)
#   - HBD            Number of Hydrogen Bond Donors (JoelLib)
#   - L5             Lipinski Rule of Five
#   - logP           Octanol/water partition coefficient
#   - MR             Molar refractivity
#   - MW             Molecular Weight
#   - nF             Number of Fluorine Atoms
#   - nHal           Number of halogen atoms
#   - spinMult       Total Spin Multiplicity
#   - TPSA           Topological polar surface area
# @param [URI] compound_uri Compound URI
# @return [Sting] descriptor value
post '/openbabel/:property' do
	obconversion = OpenBabel::OBConversion.new
	obmol = OpenBabel::OBMol.new
  compound = OpenTox::Compound.new params[:compound_uri]
	obconversion.set_in_and_out_formats 'inchi', 'can'
  obconversion.read_string obmol, compound.to_inchi
  obmol_methods = ["num_atoms", "num_bonds", "num_hvy_atoms", "num_residues", "num_rotors", "get_formula", "get_energy", "get_mol_wt", "get_exact_mass", "get_total_charge", "get_total_spin_multiplicity"]

  descriptor_methods = [ "HBA1", "HBA2", "HBD", "L5", "logP", "MR", "MW", "nF", "nHal", "spinMult", "TPSA" ]
  if obmol_methods.include? params[:property].underscore
    eval("obmol.#{params[:property].underscore}").to_s
  elsif descriptor_methods.include? params[:property]
    descriptor = OpenBabel::OBDescriptor.find_type(params[:property])
    descriptor.predict(obmol).to_s
  else
    halt 404, "Cannot calculate property #{params[:property]} with OpenBabel"
  end
end
