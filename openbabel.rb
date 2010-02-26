get '/openbabel/:smiles/:property/?' do 
	obconversion = OpenBabel::OBConversion.new
	obmol = OpenBabel::OBMol.new
	obconversion.set_in_and_out_formats 'smi', 'can'
	case params[:property]
	when 'logP'
		#logP = OpenBabel::OBLogP.new
		#logP.predict(obmol)
		"not yet implemented"
	when 'psa'
		#psa = OpenBabel::OBPSA.new
		"not yet implemented"
	when 'mr'
		#mr = OpenBabel::OBMR.new
		"not yet implemented"
	else
		begin
			obconversion.read_string obmol, params[:smiles]
		rescue
			halt 404, "Incorrect Smiles string #{params[:smiles]}"
		end
		begin
			eval("obmol.#{params[:property]}").to_s
		rescue
			halt 404, "Could not calculate property #{params[:property]}"
		end
	end
end
