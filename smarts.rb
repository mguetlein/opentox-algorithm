get '/match/compound/*/smarts/*/?' do
	"#{OpenTox::Compound.new(:inchi => params[:splat][0]).match?(params[:splat][1])}"
end
