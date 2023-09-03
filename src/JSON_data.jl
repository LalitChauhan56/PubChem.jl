struct CompoundProperties end
Symbolics.option_to_metadata_type(::Val{:properties}) = CompoundProperties

# Send HTTP request to API
function get_json_from_url(url)
    # Send HTTP GET request
    resp = HTTP.get(url)

    # Convert HTTP response to a string and parse it as JSON
    return JSON.parse(String(resp.body))
end

# Get JSON using the name of the compound
function get_json_from_name(name)
    return get_json_from_url("https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$name/json")
end

# Get JSON using the CID of the compound
function get_json_from_cid(cid)
    return get_json_from_url("https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/$cid/json")
end

"""
    get_compound(name::AbstractString)

Return a JSON file containing chemical properties of the given compound.
"""

get_compound(x::Integer) = get_json_from_cid(x)
get_compound(x::AbstractString) = get_json_from_name(x)
get_compound(x::Symbol) = get_json_from_name(x)

# Extracts chemical properties from the JSON
function extract_properties(data)
    properties = Dict()

    # Get the information section from the JSON
    info = data["PC_Compounds"][1]["props"]

    # Extract charge information
    charge = data["PC_Compounds"][1]["charge"]

    # Iterate over the 'info' array
    for item in info
        # Get the label and name of the property
        label = get(item["urn"], "label", "")
        name = get(item["urn"], "name", "")

        # Check if the property is one of the ones we're interested in
        if label == "IUPAC Name" && name == "Preferred"
            properties["IUPAC_Name_Preferred"] = get(item, "value", "")["sval"]
        elseif label == "IUPAC Name" && name == "Traditional"
            properties["IUPAC_Name_Traditional"] = get(item, "value", "")["sval"]
        elseif label == "Molecular Weight"
            properties["Molecular_weight"] = parse(Float64, get(item, "value", "")["sval"])
        elseif label == "Molecular Formula"
            properties["Molecular_formula"] = get(item, "value", "")["sval"]
        elseif label == "Mass"
            properties["Molecular_mass"] = parse(Float64, get(item, "value", "")["sval"])        
        elseif label == "SMILES"
            properties["Smiles"] = get(item, "value", "")["sval"]
        end
    end

    # Store the charge information
    properties["Charge"] = charge

    # Return the properties
    return properties
end

# Returns a dictionary of chemical properties
function get_compound_properties(name)
    # Fetch compound data
    compound_data = get_compound(name)

    # Extract and return properties
    return extract_properties(compound_data)
end

"""
    @attach_metadata

Attach chemical properties fetched from PubChem to the given speices

Example:
```julia
@variables t
@species H2(t)
@attach_metadata H2
```

"""

macro attach_metadata(variable, name)
    properties = get_compound_properties(name)
    setmetadata_expr = :($(variable) = ModelingToolkit.setmetadata($(variable),PubChem.CompoundProperties,$properties))
    escaped_setmetadata_expr = esc(setmetadata_expr)
    return Expr(:block,escaped_setmetadata_expr)
end

macro attach_metadata(variable)
    properties = get_compound_properties(variable)
    setmetadata_expr = :($(variable) = ModelingToolkit.setmetadata($(variable),PubChem.CompoundProperties,$properties))
    escaped_setmetadata_expr = esc(setmetadata_expr)
    return Expr(:block,escaped_setmetadata_expr)
end
