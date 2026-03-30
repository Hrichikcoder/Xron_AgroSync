# Just paste your exact list and dictionary from your original code here.

class_names = [
    "Apple__Apple_scab", "Apple__Black_rot",
"Apple__Cedar_apple_rust", "Apple__healthy",
    "Blueberry__healthy", "Cassava", "Cassava__Healthy",
"Cherry_(including_sour)__Powdery_mildew",
    "Cherry_(including_sour)__healthy", "Coffee__Miner",
"Coffee__Phoma", "Coffee__Rust",
    "Corn_(maize)_Common_rust", "Corn__(maize)__Cercospora__leaf__spot Gray_leaf_spot",
    "Corn_(maize)__Northern_Leaf_Blight", "Corn_(maize)__healthy",
"Corn__Healthy",
    "Cotton__Aphid", "Cotton__Healthy", "Grape__Black_rot",
"Grape__Esca_(Black_Measles)",
    "Grape__Leaf_blight_(Isariopsis_Leaf_Spot)", "Grape__healthy",
"Orange__Haunglongbing_(Citrus_greening)",
    "Peach__Bacterial_spot", "Peach__healthy",
"Pepper,_bell__Bacterial_spot", "Pepper,_bell__healthy",
    "Potato__Early_blight", "Potato__Late_blight", "Potato__healthy",
"Raspberry__healthy",
    "Rice__Bacterial_blight", "Rice__Blast", "Rice__Brown_spot", "Rice__Tungro",
    "Soybean__healthy", "Squash__Powdery_mildew",
"Strawberry__Leaf_scorch", "Strawberry__healthy",
    "Tea__Anthracnose", "Tomato__Bacterial_spot",
"Tomato__Early_blight", "Tomato__Late_blight",
    "Tomato__Leaf_Mold", "Tomato__Septoria_leaf_spot",
"Tomato__Spider_mites Two-spotted_spider_mite",
    "Tomato__Target_Spot", "Tomato__Tomato_Yellow_Leaf_Curl_Virus",
"Tomato__Tomato_mosaic_virus",
    "Tomato__healthy", "Wheat__Healthy"
]
disease_details_db = {
<<<<<<< HEAD
    "Apple - Apple Scab": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Mancozeb 2.5 g/L every 10-14 days", "Captan 2 g/L", "Myclobutanil 1 g/L in severe cases"],
            "cultural": ["Remove fallen infected leaves", "Prune trees to improve airflow", "Avoid overhead irrigation"],
            "biological": ["Apply Bacillus subtilis based bio-fungicides"],
            "maintenance": ["Ensure proper orchard sanitation", "Monitor leaves closely during wet spring weather"],
            "notes": "Start spraying at green tip stage. Spores spread rapidly in rainy weather."
        }
    },
    "Apple - Black Rot": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Copper oxychloride 0.3%", "Tebuconazole 1 ml/L"],
            "cultural": ["Remove mummified fruits", "Prune infected branches 8-10 cm below lesion"],
            "biological": ["Use Trichoderma harzianum soil applications"],
            "maintenance": ["Burn or deeply bury infected prunings", "Maintain tree vigor with proper fertilization"],
            "notes": "Infection often starts in dead bark or mummified fruit left on the tree."
        }
    },
    "Apple - Cedar Apple Rust": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Propiconazole 1 ml/L at pink bud stage", "Myclobutanil applications"],
            "cultural": ["Remove nearby juniper/cedar plants", "Prune infected shoots"],
            "biological": ["Application of bio-fungicides during spore release windows"],
            "maintenance": ["Monitor nearby cedar trees for galls in early spring"],
            "notes": "This rust requires two hosts (apple and cedar) to complete its lifecycle."
        }
    },
    "Apple - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Maintain clean orchard floor", "Practice annual crop rotation for undergrowth"],
            "biological": ["Encourage natural predators like ladybugs and lacewings"],
            "maintenance": ["Balanced NPK fertilization", "Preventive copper spray before flowering", "Regular pruning"],
            "notes": "Plant shows excellent health. Continue standard monitoring."
        }
    },
    "Blueberry - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Renew organic mulch annually"],
            "biological": ["Encourage bees for optimal pollination"],
            "maintenance": ["Maintain soil pH 4.5-5.5", "Avoid waterlogging", "Prune dead wood annually"],
            "notes": "Foliage is healthy. Ensure consistent soil acidity."
        }
    },
    "Cassava": {
        "type": "General Disease Prevention",
        "remedy": {
            "chemical": ["Use systemic insecticides for severe whitefly infestations"],
            "cultural": ["Use virus-free stem cuttings", "Control whiteflies", "Crop rotation"],
            "biological": ["Introduce predatory mites for pest control"],
            "maintenance": ["Weed regularly to reduce alternative pest hosts"],
            "notes": "Prevention is key as viral cassava diseases have no cure."
        }
    },
    "Cassava - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Practice crop rotation with legumes"],
            "biological": ["Maintain soil organic matter for root health"],
            "maintenance": ["Use certified disease-free planting material", "Ensure proper drainage"],
            "notes": "Plant is thriving. Continue good agricultural practices."
        }
    },
    "Cherry (Including Sour) - Powdery Mildew": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Sulfur 2 g/L", "Hexaconazole 1 ml/L"],
            "cultural": ["Prune overcrowded branches", "Avoid excess nitrogen fertilizer"],
            "biological": ["Spray neem oil extract (1%) as a preventive measure"],
            "maintenance": ["Ensure good sunlight penetration through canopy thinning"],
            "notes": "Mildew thrives in high humidity but not in direct rain."
        }
    },
    "Cherry (Including Sour) - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No active chemical treatment needed"],
            "cultural": ["Keep the base of the tree weed-free"],
            "biological": ["Protect natural pollinator habitats"],
            "maintenance": ["Dormant copper spray", "Annual pruning during dry weather"],
            "notes": "Tree is healthy. Watch out for sudden late frosts."
        }
    },
    "Coffee - Miner": {
        "type": "Insect Infestation",
        "remedy": {
            "chemical": ["Chlorantraniliprole 0.3 ml/L", "Imidacloprid 0.3 ml/L"],
            "cultural": ["Remove and destroy heavily mined leaves"],
            "biological": ["Encourage natural predators like parasitic wasps"],
            "maintenance": ["Monitor leaf damage closely during dry seasons"],
            "notes": "Leaf miners reduce photosynthetic area, impacting yield."
        }
    },
    "Coffee - Phoma": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Copper fungicide 3 g/L", "Mancozeb 2.5 g/L"],
            "cultural": ["Provide proper shade management", "Avoid planting in strong wind corridors"],
            "biological": ["Use Bacillus-based biofungicides"],
            "maintenance": ["Install windbreaks to prevent leaf injury where spores enter"],
            "notes": "Often attacks coffee plants recovering from cold stress or wind damage."
        }
    },
    "Coffee - Rust": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Hexaconazole 1 ml/L", "Propiconazole 1 ml/L"],
            "cultural": ["Increase spacing between coffee bushes", "Prune to increase airflow"],
            "biological": ["Apply Lecanicillium lecanii bio-fungicide"],
            "maintenance": ["Apply foliar nutrients to help plants recover foliage"],
            "notes": "One of the most devastating coffee diseases globally."
        }
    },
    "Corn (Maize) Common Rust": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Propiconazole 1 ml/L", "Azoxystrobin applications"],
            "cultural": ["Use resistant corn hybrids in future plantings", "Avoid early planting"],
            "biological": ["Apply Trichoderma harzianum to crop residues post-harvest"],
            "maintenance": ["Monitor lower leaves constantly during cool, humid weather"],
            "notes": "Rust pustules usually appear on both upper and lower leaf surfaces."
        }
    },
    "Corn (Maize) - Cercospora Leaf Spot Gray Leaf Spot": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Azoxystrobin 1 ml/L", "Mancozeb 2.5 g/L"],
            "cultural": ["Crop rotation 2-3 years", "Deep plow crop residue"],
            "biological": ["Use compost teas to boost foliar immunity"],
            "maintenance": ["Control grassy weeds that harbor the fungus"],
            "notes": "Lesions are distinctly rectangular, restricted by leaf veins."
        }
    },
    "Corn (Maize) - Northern Leaf Blight": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Mancozeb + Carbendazim spray", "Pyraclostrobin applications"],
            "cultural": ["Bury infected crop debris deeply", "Use resistant seed varieties"],
            "biological": ["Bacillus subtilis foliar sprays early in the season"],
            "maintenance": ["Scout fields before tasseling for cigar-shaped lesions"],
            "notes": "Can cause severe yield loss if it strikes before silking."
        }
    },
    "Corn (Maize) - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Rotate with soybeans to fix nitrogen"],
            "biological": ["Encourage Trichogramma wasps for borer control"],
            "maintenance": ["Balanced nitrogen application", "Good field drainage"],
            "notes": "Crop is developing well. Maintain soil moisture."
        }
    },
    "Corn - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Maintain weed-free rows"],
            "biological": ["Promote healthy soil microbiome with organic matter"],
            "maintenance": ["Proper spacing", "Balanced fertilization"],
            "notes": "No disease detected. Continue normal agricultural schedule."
        }
    },
    "Cotton - Aphid": {
        "type": "Insect Infestation",
        "remedy": {
            "chemical": ["Imidacloprid 0.3 ml/L", "Thiamethoxam 0.25 g/L"],
            "cultural": ["Avoid excessive nitrogen application which attracts aphids"],
            "biological": ["Release ladybird beetles and lacewings"],
            "maintenance": ["Monitor leaf undersides and terminal buds"],
            "notes": "Aphids secrete honeydew which leads to sooty mold."
        }
    },
    "Cotton - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Plant trap crops nearby if pest pressure is historically high"],
            "biological": ["Preserve natural enemy populations"],
            "maintenance": ["Integrated Pest Management", "Regular field scouting"],
            "notes": "Crop shows vigorous growth."
        }
    },
    "Grape - Black Rot": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Captan 2 g/L", "Mancozeb 2.5 g/L"],
            "cultural": ["Remove and destroy infected berries and mummies"],
            "biological": ["Apply bio-fungicides directly to the fruit clusters"],
            "maintenance": ["Improve canopy airflow with proper trellis management"],
            "notes": "Infected berries shrivel into hard, black mummies."
        }
    },
    "Grape - Esca (Black Measles)": {
        "type": "Fungal/Wood Disease",
        "remedy": {
            "chemical": ["Fosetyl-aluminum injections (consult professional)"],
            "cultural": ["Remove infected vines completely", "Disinfect pruning tools between cuts"],
            "biological": ["Apply Trichoderma paints to fresh pruning wounds"],
            "maintenance": ["Delay pruning until late winter to minimize wound infection"],
            "notes": "No complete cure available. Focus on preventing spread to healthy vines."
        }
    },
    "Grape - Leaf Blight (Isariopsis Leaf Spot)": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Copper fungicide 3 g/L"],
            "cultural": ["Rake and burn fallen leaves in autumn"],
            "biological": ["Apply Bacillus subtilis foliar sprays"],
            "maintenance": ["Ensure vines are not overcrowded"],
            "notes": "Causes premature defoliation, weakening the vine for winter."
        }
    },
    "Grape - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Plant cover crops between vine rows"],
            "biological": ["Encourage predatory mites to control spider mites"],
            "maintenance": ["Drip irrigation", "Proper canopy management"],
            "notes": "Vines are healthy. Focus on cluster thinning for fruit quality."
        }
    },
    "Orange - Haunglongbing (Citrus Greening)": {
        "type": "Bacterial Infection",
        "remedy": {
            "chemical": ["Imidacloprid for psyllid vector control", "Foliar nutrient sprays to prolong tree life"],
            "cultural": ["Remove heavily infected trees immediately", "Control Asian citrus psyllid"],
            "biological": ["Release Tamarixia radiata wasps to prey on psyllids"],
            "maintenance": ["Implement aggressive psyllid monitoring programs"],
            "notes": "Fatal to the tree. Eradication of the vector is the only defense."
        }
    },
    "Peach - Bacterial Spot": {
        "type": "Bacterial Infection",
        "remedy": {
            "chemical": ["Copper sprays during dormancy", "Oxytetracycline during growing season"],
            "cultural": ["Avoid planting susceptible varieties in windy, sandy sites"],
            "biological": ["Use bacteriophage-based treatments if available"],
            "maintenance": ["Maintain tree vigor to resist defoliation impacts"],
            "notes": "Causes shot-hole appearance on leaves and spotting on fruit."
        }
    },
    "Peach - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Clear fallen fruit promptly"],
            "biological": ["Encourage braconid wasps for borer control"],
            "maintenance": ["Dormant pruning", "Thinning of fruits"],
            "notes": "Tree is healthy. Ensure adequate watering during fruit swell."
        }
    },
    "Pepper, Bell - Bacterial Spot": {
        "type": "Bacterial Infection",
        "remedy": {
            "chemical": ["Copper hydroxide 2 g/L tank-mixed with Mancozeb"],
            "cultural": ["Crop rotation (avoid nightshades)", "Use disease-free seeds"],
            "biological": ["Apply Bacillus amyloliquefaciens"],
            "maintenance": ["Use drip irrigation instead of overhead sprinklers"],
            "notes": "Spreads rapidly during warm, driving rainstorms."
        }
    },
    "Pepper, Bell - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Use reflective mulches to repel aphids"],
            "biological": ["Maintain healthy soil flora"],
            "maintenance": ["Maintain optimal soil moisture", "Provide support for stems"],
            "notes": "Excellent foliage health."
        }
    },
    "Potato - Early Blight": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Chlorothalonil 2 g/L", "Mancozeb 2.5 g/L"],
            "cultural": ["Allow tubers to mature fully before harvest", "Crop rotation"],
            "biological": ["Apply bio-fungicides targeting Alternaria solani"],
            "maintenance": ["Maintain consistent soil moisture to prevent plant stress"],
            "notes": "Look for characteristic 'bullseye' concentric rings on older leaves."
        }
    },
    "Potato - Late Blight": {
        "type": "Water Mold (Oomycete)",
        "remedy": {
            "chemical": ["Metalaxyl + Mancozeb 2.5 g/L", "Dimethomorph 1 g/L"],
            "cultural": ["Destroy cull piles", "Use certified disease-free seed potatoes"],
            "biological": ["Limited biological control; rely on resistant varieties"],
            "maintenance": ["Kill vines 2 weeks before harvest to protect tubers"],
            "notes": "Highly contagious. Can destroy a field in days under wet conditions."
        }
    },
    "Potato - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Rotate with non-solanaceous crops"],
            "biological": ["Foster ground beetles in the soil"],
            "maintenance": ["Hilling to protect tubers from sun", "Proper irrigation"],
            "notes": "Plants are robust and healthy."
        }
    },
    "Raspberry - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Remove wild brambles nearby"],
            "biological": ["Attract predatory mites"],
            "maintenance": ["Pruning old canes immediately after harvest", "Trellising"],
            "notes": "Healthy foliage. Ensure good air circulation through the trellis."
        }
    },
    "Rice - Bacterial Blight": {
        "type": "Bacterial Infection",
        "remedy": {
            "chemical": ["Streptocycline 1 g/10L + Copper Oxychloride"],
            "cultural": ["Avoid excess nitrogen", "Drain field temporarily to reduce humidity"],
            "biological": ["Pseudomonas fluorescens seed treatment and foliar spray"],
            "maintenance": ["Keep fields free of weeds that harbor the bacteria"],
            "notes": "Often enters through leaf wounds after heavy winds or typhoons."
        }
    },
    "Rice - Blast": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Tricyclazole 0.6 g/L", "Isoprothiolane 1.5 ml/L"],
            "cultural": ["Split nitrogen applications", "Avoid drought stress"],
            "biological": ["Apply Trichoderma viride"],
            "maintenance": ["Flooding the field can reduce leaf blast severity"],
            "notes": "Can infect leaves, collars, nodes, and panicles."
        }
    },
    "Rice - Brown Spot": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Mancozeb 2.5 g/L", "Propiconazole 1 ml/L"],
            "cultural": ["Apply balanced nutrients including silicon", "Amend soil with organic matter"],
            "biological": ["Bacillus subtilis seed treatments"],
            "maintenance": ["Ensure adequate potassium levels in soil"],
            "notes": "Often an indicator of poor soil nutrition or water stress."
        }
    },
    "Rice - Tungro": {
        "type": "Viral Infection",
        "remedy": {
            "chemical": ["Control green leafhopper vectors with Imidacloprid"],
            "cultural": ["Destroy infected stubbles", "Practice synchronized planting in the region"],
            "biological": ["Encourage spiders and water bugs that eat leafhoppers"],
            "maintenance": ["Delay planting to break the insect vector cycle"],
            "notes": "Leaves turn yellow-orange starting from the tip."
        }
    },
    "Soybean - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Ensure proper row spacing"],
            "biological": ["Seed inoculation with Rhizobium bacteria"],
            "maintenance": ["Timely weed management", "Monitor for aphids"],
            "notes": "Healthy canopy. Nodulation should be occurring at roots."
        }
    },
    "Squash - Powdery Mildew": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Sulfur dust", "Myclobutanil 1 g/L"],
            "cultural": ["Plant in full sun", "Space plants widely"],
            "biological": ["Spray a mixture of milk and water (1:9 ratio) early in infection"],
            "maintenance": ["Water at the base to keep foliage dry"],
            "notes": "Looks like white talcum powder dusted over the leaves."
        }
    },
    "Strawberry - Leaf Scorch": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Captan 2 g/L", "Thiophanate-methyl 1 g/L"],
            "cultural": ["Remove dead or infected leaves frequentyl", "Ensure good drainage"],
            "biological": ["Apply Trichoderma-based bio-fungicides to the crown"],
            "maintenance": ["Avoid dense canopies and weed competition"],
            "notes": "Irregular dark purple/brown spots that lack the light center of leaf spot."
        }
    },
    "Strawberry - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["No chemical treatment required"],
            "cultural": ["Use clean straw for mulching"],
            "biological": ["Introduce predatory mites for spider mite prevention"],
            "maintenance": ["Mulching to keep fruit off soil", "Renovation after harvest"],
            "notes": "Vigorous green leaves. Maintain bird netting if fruiting."
        }
    },
    "Tea - Anthracnose": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Copper oxychloride 2.5 g/L", "Hexaconazole 1 ml/L"],
            "cultural": ["Pluck affected shoots and destroy them", "Improve field drainage"],
            "biological": ["Foliar application of Pseudomonas fluorescens"],
            "maintenance": ["Regulate shade to allow sunlight penetration"],
            "notes": "Thrives in warm, highly humid conditions."
        }
    },
    "Tomato - Bacterial Spot": {
        "type": "Bacterial Infection",
        "remedy": {
            "chemical": ["Copper hydroxide 2 g/L", "Streptomycin sulfate sprays"],
            "cultural": ["Avoid overhead watering", "Strict 3-year crop rotation"],
            "biological": ["Apply bacteriophages specific to Xanthomonas"],
            "maintenance": ["Disinfect stakes and pruning tools between plants"],
            "notes": "Do not work among wet plants, as this spreads the bacteria."
        }
    },
    "Tomato - Early Blight": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Chlorothalonil 2 g/L", "Azoxystrobin 1 ml/L"],
            "cultural": ["Remove lower leaves as they yellow", "Mulch to prevent soil splashing"],
            "biological": ["Bacillus subtilis foliar applications"],
            "maintenance": ["Provide adequate nitrogen to delay lower leaf senescence"],
            "notes": "Starts on older, lower leaves first with target-like rings."
        }
    },
    "Tomato - Late Blight": {
        "type": "Water Mold (Oomycete)",
        "remedy": {
            "chemical": ["Metalaxyl + Mancozeb 2.5 g/L", "Cymoxanil + Mancozeb"],
            "cultural": ["Destroy all infected plants immediately", "Do not compost infected tissue"],
            "biological": ["Actinovate (Streptomyces lydicus) as a preventative"],
            "maintenance": ["Ensure aggressive airflow in greenhouses"],
            "notes": "Can destroy an entire tomato crop in days. Requires immediate action."
        }
    },
    "Tomato - Leaf Mold": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Chlorothalonil 2 g/L", "Copper based fungicides"],
            "cultural": ["Improve greenhouse ventilation", "Increase plant spacing"],
            "biological": ["Apply bio-fungicides early in the high-humidity season"],
            "maintenance": ["Keep relative humidity below 85% if growing indoors"],
            "notes": "Pale green or yellow spots on top of leaves, olive-green mold underneath."
        }
    },
    "Tomato - Septoria Leaf Spot": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Chlorothalonil 2 g/L", "Mancozeb 2.5 g/L"],
            "cultural": ["Clear tomato debris at end of season", "Use thick mulch layers"],
            "biological": ["Apply neem oil or Serenade (Bacillus subtilis)"],
            "maintenance": ["Water at the base only"],
            "notes": "Numerous small, circular spots with dark borders and gray centers."
        }
    },
    "Tomato - Spider Mites Two-Spotted Spider Mite": {
        "type": "Arachnid Infestation",
        "remedy": {
            "chemical": ["Abamectin 1 ml/L", "Spiromesifen 1 ml/L", "Insecticidal soaps"],
            "cultural": ["Hose down plants with strong water jets to dislodge mites"],
            "biological": ["Release predatory mites like Phytoseiulus persimilis"],
            "maintenance": ["Maintain adequate irrigation, as mites target drought-stressed plants"],
            "notes": "Look for fine webbing under leaves and a stippled, yellowed appearance."
        }
    },
    "Tomato - Target Spot": {
        "type": "Fungal Infection",
        "remedy": {
            "chemical": ["Chlorothalonil 2 g/L", "Mancozeb 2.5 g/L"],
            "cultural": ["Remove old crop residue", "Ensure good canopy airflow"],
            "biological": ["Preventative spraying with bio-fungicides"],
            "maintenance": ["Prune lower suckers to keep foliage off the ground"],
            "notes": "Lesions on fruit have sunken centers."
        }
    },
    "Tomato - Tomato Yellow Leaf Curl Virus": {
        "type": "Viral Infection",
        "remedy": {
            "chemical": ["Control whitefly vectors with Imidacloprid or Thiamethoxam"],
            "cultural": ["Use resistant varieties (TYLCV resistant)", "Use insect-proof netting"],
            "biological": ["Use yellow sticky traps to catch whiteflies"],
            "maintenance": ["Uproot and burn infected plants immediately"],
            "notes": "Stunted growth with severe upward curling and yellowing of leaf margins."
        }
    },
    "Tomato - Tomato Mosaic Virus": {
        "type": "Viral Infection",
        "remedy": {
            "chemical": ["No chemical cure exists for viruses"],
            "cultural": ["Remove and destroy infected plants", "Do not use tobacco products near plants"],
            "biological": ["Plant resistant tomato cultivars"],
            "maintenance": ["Wash hands with soap and disinfect tools thoroughly before handling plants"],
            "notes": "Highly mechanically transmissible through hands, tools, and clothing."
        }
    },
    "Tomato - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["None required"],
            "cultural": ["Rotate planting location annually"],
            "biological": ["Plant companion crops like basil or marigolds to deter pests"],
            "maintenance": ["Staking and pruning", "Consistent deep watering to prevent blossom end rot"],
            "notes": "Leaves are healthy. Keep up with calcium supplementation if fruiting."
        }
    },
    "Wheat - Healthy": {
        "type": "Healthy Plant",
        "remedy": {
            "chemical": ["None required"],
            "cultural": ["Timely sowing", "Use certified seeds"],
            "biological": ["Foster healthy soil microbiology"],
            "maintenance": ["Appropriate stage-wise fertilization", "Monitor for rust during cool, wet periods"],
            "notes": "Crop is healthy and showing normal development."
        }
=======
  "Apple__Apple_scab": {
    "type": "fungal",
    "remedy": {
      "cultural": [
        "Remove fallen infected leaves",
        "Prune trees to improve airflow",
        "Avoid overhead irrigation"
      ],
      "chemical": [
        "Mancozeb 2.5 g/L every 10-14 days",
        "Captan 2 g/L",
        "Myclobutanil 1 g/L in severe cases"
      ],
      "notes": "Start spraying at green tip stage."
>>>>>>> 47de89d327a19276121a716409e871c3bd92273a
    }
  },
  "Apple__Black_rot": {
    "type": "fungal",
    "remedy": {
      "cultural": [
        "Remove mummified fruits",
        "Prune infected branches 8-10 cm below lesion"
      ],
      "chemical": [
        "Copper oxychloride 0.3%",
        "Tebuconazole 1 ml/L"
      ]
    }
  },
  "Apple__Cedar_apple_rust": {
    "type": "fungal",
    "remedy": {
      "cultural": [
        "Remove nearby juniper plants",
        "Prune infected shoots"
      ],
      "chemical": [
        "Propiconazole 1 ml/L at pink bud stage"
      ]
    }
  },
  "Apple__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Balanced NPK fertilization",
        "Preventive copper spray before flowering",
        "Regular pruning"
      ]
    }
  },
  "Blueberry__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Maintain soil pH 4.5-5.5",
        "Avoid waterlogging"
      ]
    }
  },
  "Cassava": {
    "type": "general_disease_prevention",
    "remedy": {
      "cultural": [
        "Use virus-free stem cuttings",
        "Control whiteflies",
        "Crop rotation"
      ]
    }
  },
  "Cassava__Healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Use certified disease-free planting material",
        "Ensure proper drainage"
      ]
    }
  },
  "Cherry_(including_sour)__Powdery_mildew": {
    "type": "fungal",
    "remedy": {
      "cultural": [
        "Prune overcrowded branches",
        "Avoid excess nitrogen fertilizer"
      ],
      "chemical": [
        "Sulfur 2 g/L",
        "Hexaconazole 1 ml/L"
      ]
    }
  },
  "Cherry_(including_sour)__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Dormant copper spray",
        "Annual pruning"
      ]
    }
  },
  "Coffee__Miner": {
    "type": "insect",
    "remedy": {
      "cultural": [
        "Remove mined leaves",
        "Encourage natural predators"
      ],
      "chemical": [
        "Chlorantraniliprole 0.3 ml/L",
        "Imidacloprid 0.3 ml/L"
      ]
    }
  },
  "Coffee__Phoma": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Copper fungicide 3 g/L",
        "Mancozeb 2.5 g/L"
      ]
    }
  },
  "Coffee__Rust": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Hexaconazole 1 ml/L",
        "Propiconazole 1 ml/L"
      ]
    }
  },
  "Corn_(maize)_Common_rust": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Propiconazole 1 ml/L"
      ],
      "cultural": [
        "Use resistant hybrids"
      ]
    }
  },
  "Corn_(maize)__Cercospora_leaf_spot Gray_leaf_spot": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Azoxystrobin 1 ml/L",
        "Mancozeb 2.5 g/L"
      ],
      "cultural": [
        "Crop rotation 2-3 years",
        "Remove crop residue"
      ]
    }
  },
  "Corn_(maize)__Northern_Leaf_Blight": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Mancozeb + Carbendazim spray"
      ]
    }
  },
  "Corn_(maize)__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Balanced nitrogen application",
        "Good field drainage"
      ]
    }
  },
  "Corn__Healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Proper spacing",
        "Balanced fertilization"
      ]
    }
  },
  "Cotton__Aphid": {
    "type": "insect",
    "remedy": {
      "chemical": [
        "Imidacloprid 0.3 ml/L",
        "Thiamethoxam 0.25 g/L"
      ],
      "biological": [
        "Release ladybird beetles"
      ]
    }
  },
  "Cotton__Healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Integrated Pest Management",
        "Regular field scouting"
      ]
    }
  },
  "Grape__Black_rot": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Captan 2 g/L",
        "Mancozeb 2.5 g/L"
      ],
      "cultural": [
        "Remove infected berries"
      ]
    }
  },
  "Grape__Esca_(Black_Measles)": {
    "type": "fungal",
    "remedy": {
      "cultural": [
        "Remove infected vines",
        "Disinfect pruning tools"
      ],
      "notes": "No complete cure available."
    }
  },
  "Grape__Leaf_blight_(Isariopsis_Leaf_Spot)": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Copper fungicide 3 g/L"
      ]
    }
  },
  "Grape__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Drip irrigation",
        "Proper canopy management"
      ]
    }
  },
  "Orange__Haunglongbing_(Citrus_greening)": {
    "type": "bacterial",
    "remedy": {
      "cultural": [
        "Remove infected trees",
        "Control Asian citrus psyllid"
      ],
      "chemical": [
        "Imidacloprid for psyllid control"
      ]
    }
  },
  "Peach__Bacterial_spot": {
    "type": "bacterial",
    "remedy": {
      "chemical": [
        "Copper sprays during dormancy",
        "Oxytetracycline during growing season"
      ]
    }
  },
  "Peach__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Dormant pruning",
        "Thinning of fruits"
      ]
    }
  },
  "Pepper,_bell__Bacterial_spot": {
    "type": "bacterial",
    "remedy": {
      "chemical": [
        "Copper hydroxide 2 g/L"
      ],
      "cultural": [
        "Crop rotation",
        "Use disease-free seeds"
      ]
    }
  },
  "Pepper,_bell__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Maintain optimal soil moisture",
        "Provide support for stems"
      ]
    }
  },
  "Potato__Early_blight": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Chlorothalonil 2 g/L",
        "Mancozeb 2.5 g/L"
      ]
    }
  },
  "Potato__Late_blight": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Metalaxyl + Mancozeb 2.5 g/L",
        "Dimethomorph 1 g/L"
      ],
      "cultural": [
        "Destroy cull piles",
        "Use certified seed potatoes"
      ]
    }
  },
  "Potato__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Hilling",
        "Proper irrigation"
      ]
    }
  },
  "Raspberry__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Pruning old canes",
        "Trellising"
      ]
    }
  },
  "Rice__Bacterial_blight": {
    "type": "bacterial",
    "remedy": {
      "chemical": [
        "Streptocycline 1 g/10L"
      ],
      "cultural": [
        "Avoid excess nitrogen",
        "Drain field temporarily"
      ]
    }
  },
  "Rice__Blast": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Tricyclazole 0.6 g/L",
        "Isoprothiolane 1.5 ml/L"
      ]
    }
  },
  "Rice__Brown_spot": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Mancozeb 2.5 g/L",
        "Propiconazole 1 ml/L"
      ],
      "cultural": [
        "Apply balanced nutrients including silicon"
      ]
    }
  },
  "Rice__Tungro": {
    "type": "viral",
    "remedy": {
      "chemical": [
        "Control green leafhopper vectors with Imidacloprid"
      ],
      "cultural": [
        "Destroy stubbles",
        "Synchronized planting"
      ]
    }
  },
  "Soybean__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Seed inoculation with Rhizobium",
        "Weed management"
      ]
    }
  },
  "Squash__Powdery_mildew": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Sulfur dust",
        "Myclobutanil 1 g/L"
      ]
    }
  },
  "Strawberry__Leaf_scorch": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Captan 2 g/L",
        "Thiophanate-methyl 1 g/L"
      ]
    }
  },
  "Strawberry__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Mulching",
        "Renovation after harvest"
      ]
    }
  },
  "Tea__Anthracnose": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Copper oxychloride 2.5 g/L",
        "Hexaconazole 1 ml/L"
      ],
      "cultural": [
        "Pluck affected shoots",
        "Improve drainage"
      ]
    }
  },
  "Tomato__Bacterial_spot": {
    "type": "bacterial",
    "remedy": {
      "chemical": [
        "Copper hydroxide 2 g/L",
        "Streptomycin sulfate"
      ],
      "cultural": [
        "Avoid overhead watering",
        "Crop rotation"
      ]
    }
  },
  "Tomato__Early_blight": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Chlorothalonil 2 g/L",
        "Azoxystrobin 1 ml/L"
      ]
    }
  },
  "Tomato__Late_blight": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Metalaxyl + Mancozeb 2.5 g/L",
        "Cymoxanil + Mancozeb"
      ]
    }
  },
  "Tomato__Leaf_Mold": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Chlorothalonil 2 g/L",
        "Copper fungicide"
      ],
      "cultural": [
        "Improve greenhouse ventilation",
        "Increase plant spacing"
      ]
    }
  },
  "Tomato__Septoria_leaf_spot": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Chlorothalonil 2 g/L",
        "Mancozeb 2.5 g/L"
      ]
    }
  },
  "Tomato__Spider_mites Two-spotted_spider_mite": {
    "type": "insect",
    "remedy": {
      "chemical": [
        "Abamectin 1 ml/L",
        "Spiromesifen 1 ml/L"
      ],
      "cultural": [
        "Maintain adequate irrigation",
        "Hose down plants"
      ]
    }
  },
  "Tomato__Target_Spot": {
    "type": "fungal",
    "remedy": {
      "chemical": [
        "Chlorothalonil 2 g/L",
        "Mancozeb 2.5 g/L"
      ]
    }
  },
  "Tomato__Tomato_Yellow_Leaf_Curl_Virus": {
    "type": "viral",
    "remedy": {
      "chemical": [
        "Control whitefly vectors with Imidacloprid or Thiamethoxam"
      ],
      "cultural": [
        "Use resistant varieties",
        "Use insect-proof netting"
      ]
    }
  },
  "Tomato__Tomato_mosaic_virus": {
    "type": "viral",
    "remedy": {
      "cultural": [
        "Remove and destroy infected plants",
        "Wash hands and tools thoroughly",
        "Do not use tobacco products near plants"
      ]
    }
  },
  "Tomato__healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Staking and pruning",
        "Consistent watering"
      ]
    }
  },
  "Wheat__Healthy": {
    "type": "healthy",
    "remedy": {
      "maintenance": [
        "Timely sowing",
        "Appropriate fertilization"
      ]
    }
  }
}