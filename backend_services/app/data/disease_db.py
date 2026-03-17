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