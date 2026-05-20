local p = {}
local COUNTRIES_GALLERY_NAME = "AllCountries"
local REGIONS_GALLERY_NAME = "RegionsCharts"
local hasWikidataLabel, wd = pcall(require, 'Module:Wikidata label')
if not hasWikidataLabel then
	wd = nil
end

local function translateGalleryName( galleryName, translations )
	if wd ~= nil and translations[galleryName] ~= nil and type( wd._getLabel ) == 'function' then
		local ok, translatedName = pcall(
			wd._getLabel,
			translations[galleryName],
			nil,
			'no',
			'ucfirst'
		)

		if ok and translatedName ~= nil and translatedName ~= '' then
			return translatedName
		end
	end

	return galleryName
end

local function copyTable( source )
	local result = {}
	for key, value in pairs( source ) do
		result[key] = value
	end
	return result
end

function p.image( frame )
	math.randomseed(tonumber(mw.getContentLanguage():formatDate( "U" ))*10000 + os.clock()*10000)
	local args = frame:getParent().args
	local popupConfig = {}
	local caption = ''
	popupConfig.loop = args.loop == "yes"
	if tonumber( args.start ) then
		popupConfig.start = tonumber( args.start )
	else
		popupConfig.start = 1
	end
	if args.startingView then
		popupConfig.startingView = tostring( args.startingView )
	end
	if args.language then
		popupConfig.language = tostring( args.language )
	end
	if args.location then
		popupConfig.location = tostring( args.location )
	end
	if tonumber( args.width ) then
		popupConfig.width = tonumber( args.width )
	end
	if tonumber( args.height ) then
		popupConfig.height = tonumber( args.height )
	end
	popupConfig.list = args.list
	popupConfig.file = args.file
	if args['noregisterimages'] == "false" then
	    -- Only register dependency if location is not Commons
		local location = args.location and string.lower(args.location) or ""
	    if location ~= "commons" and location ~= "" then
	        -- Register this as a dependency so that this page shows up as using all the images on the list page
	        frame:expandTemplate{ title = ':' .. args.list }
	    end
	end
	-- If we don't want to transclude for performance, maybe we could at least link
	-- however links need to actually be output on the page to register them.
	
	if args.caption then
		popupConfig.caption = "OWIDSlider-caption-" .. math.random()
		caption = tostring( mw.html.create( 'div' )
			:attr( 'id', popupConfig.caption )
			:attr( 'style', 'display: none' )
			:wikitext( args.caption )
			:done() )
	end
	if args.title then
		popupConfig.title = args.title
	end

	return tostring( mw.html.create( 'div' )
		:attr( 'class', 'OWIDSlider' )
		:attr( 'data-owidslider-config', mw.text.jsonEncode( { popupConfig } ) )
		:wikitext( args.file ) )
		.. caption .. '[[Category:Pages using gadget owidslider]]'

end

local function srcGallery( frame, galleryName, gallerySrc, baseGalleryArgs )
	local galleryArgs = copyTable( baseGalleryArgs )
	local id = mw.uri.anchorEncode( "gallery-" .. galleryName )
	galleryArgs.id = id
	local optionsArray = {}
	local galleryContents = ''
	for row in mw.text.gsplit( gallerySrc, "\n", true ) do
		local galleryRow = ''
		local year = false
		local country = false
		local region = false
		for part in mw.text.gsplit( row, "!", true ) do
			local equalSplit = mw.text.split( part, '=', true )
			if #equalSplit <= 1 then
				galleryRow = galleryRow .. part .. '|'
			else
				if equalSplit[1] == 'year' then
					year = tonumber(equalSplit[2])
				elseif equalSplit[1] == "country" then
					country = equalSplit[2]
				elseif equalSplit[1] == "region" then
					region = equalSplit[2]
				else
					galleryRow = galleryRow .. part .. '|'
				end

			end
		end
		if string.sub( galleryRow, -1 ) == '|' then
			galleryRow = string.sub( galleryRow, 1, -2 )
		end
		galleryContents = galleryContents .. galleryRow .. "\n"
		
		if galleryName == COUNTRIES_GALLERY_NAME then
			optionsArray[#optionsArray+1] = country
		elseif galleryName == REGIONS_GALLERY_NAME then
			optionsArray[#optionsArray+1] = region
		else
			optionsArray[#optionsArray+1] = year
		end
	end
	if galleryName == COUNTRIES_GALLERY_NAME then
		galleryArgs['data-owidslider-country'] = mw.text.jsonEncode( optionsArray )
	elseif galleryName == REGIONS_GALLERY_NAME then
		galleryArgs['data-owidslider-regionscharts'] = mw.text.jsonEncode( optionsArray )
	else
		galleryArgs['data-owidslider-year'] = mw.text.jsonEncode( optionsArray )	
	end
	galleryArgs['data-owidslider-name'] = galleryName

	return "\n==" .. (galleryName ~= "" and galleryName or "Gallery") .. "==\n" .. frame:extensionTag( 'gallery', galleryContents, galleryArgs )
end

function p.srcs( frame )
	local args = frame:getParent().args
	local galleryArgs = {}
	local galleryAttr = { "mode", "widths", "heights", "perrow", "caption", "showfilename", "showthumbnail", "title", "class", "lang", "dir" }
	for i, j in ipairs( galleryAttr ) do
		galleryArgs[j] = args[j]
	end
	local subItems = {}
	local output = ''
	local translations = {
		Africa = "Q15",
		Antarctica = "Q51",
		Asia = "Q48",
		Europe = "Q46",
		["North America"] = "Q49",
		Oceania = "Q55643",
		["South America"] = "Q18",
		World = "Q16502"  -- Bit iffy, maybe should be Q2 instead.
	}

	-- Make World gallery show up first.
	local galleries = {}
    for argName in pairs( args ) do
		if string.sub( argName, 0, 7 ) == "gallery" then
			table.insert( galleries, argName )
		end
	end
	table.sort( galleries, function ( x, y )
		if x == 'gallery-World' then return true end
		if y == 'gallery-World' then return false end
		if x == 'gallery-' .. REGIONS_GALLERY_NAME then return false end
		if y == 'gallery-' .. REGIONS_GALLERY_NAME then return true end
		if x == 'gallery-' .. COUNTRIES_GALLERY_NAME then return false end
		if y == 'gallery-' .. COUNTRIES_GALLERY_NAME then return true end
		return x < y
	end )

	for _, argName in ipairs( galleries ) do
		local argValue = args[argName]
		if string.sub( argName, 0, 7 ) == "gallery" then
			local rawGalleryName = string.sub( argName, 9 )
			local galleryName = translateGalleryName( rawGalleryName, translations )
			subItems[galleryName] = mw.uri.anchorEncode( "gallery-" .. galleryName )
			local srcGalleryOutput = srcGallery( frame, galleryName, argValue, galleryArgs )
			output = output .. srcGalleryOutput
		end
	end
	return mw.html.create( 'div' )
		:attr( 'class', 'owidsrclist' )
		:attr( 'id', args.id )
		:attr( 'data-owid-subids', mw.text.jsonEncode( subItems ) )
		:wikitext( output )
end


function p.gallery( frame )
	-- Seems like math.random is always seeded with 0 :(
	math.randomseed(tonumber(mw.getContentLanguage():formatDate( "U" ))*10000 + os.clock()*10000)
	local args = frame:getParent().args
	local reuseImageCaption = args.reuse_image_caption ~= nil
	local title = args["popup-title"]
	local captionId = nil
	local captionText = ''
	local galleryContents = ''
	local optionsArray = {}
	local galleryArgs = {}

	local galleryAttr = { "mode", "widths", "heights", "perrow", "caption", "showfilename", "showthumbnail", "id", "title", "class", "lang", "dir" }
	for i, j in ipairs( galleryAttr ) do
		galleryArgs[j] = args[j]
	end

	if args['popup-caption'] then
		captionId = 'OWIDSlider-caption-' .. math.random()
		captionText = tostring(
			mw.html.create( 'div' )
				:attr( 'style', 'display:none' )
				:attr( 'id', captionId )
				:wikitext( args['popup-caption'] )
		)
	end

	for row in mw.text.gsplit( args.gallery, "\n", true ) do
		local galleryRow = ''
		local popupOptions = { title = title, caption = captionId }
		for part in mw.text.gsplit( row, "!", true ) do
			local equalSplit = mw.text.split( part, '=', true )
			if #equalSplit <= 1 then
				-- be sure this really is a caption.
				if galleryRow ~= '' and
					reuseImageCaption and
					#part > 8 and
					string.find( part, " ", 1, true )
				then
					local captionId = 'OWIDSlider-caption-' .. math.random()
					local wrappedPart = tostring( mw.html.create( 'span' )
						:attr( 'id', captionId )
						:wikitext( part )
					)
					popupOptions.caption = captionId
					galleryRow = galleryRow .. wrappedPart .. '|'
				else
					galleryRow = galleryRow .. part .. '|'
				end
			else
				if equalSplit[1] == 'popup-width' then
					popupOptions.width = tonumber(equalSplit[2])
				elseif equalSplit[1] == 'popup-height' then
					popupOptions.height = tonumber(equalSplit[2])
				elseif equalSplit[1] == 'popup-loop' then
					popupOptions.loop = equalSplit[2] ~= ''
				elseif equalSplit[1] == 'popup-start' then
					popupOptions.start = tonumber(equalSplit[2])
				elseif equalSplit[1] == 'popup-startingView' then
					popupOptions.startingView = tonumber(equalSplit[2])
				elseif equalSplit[1] == 'popup-caption' then
					local captionIdForImg = 'OWIDSlider-caption-' .. math.random()
					captionText = captionText .. tostring( mw.html.create( 'div' )
						:attr( 'id', captionIdForImg )
						:css( 'display', 'none' )
						:wikitext( table.concat( equalSplit, '=', 2 ) )
					)
					popupOptions.caption = captionIdForImg
				elseif equalSplit[1] == 'popup-title' then
					popupOptions.title = table.concat( equalSplit, '=', 2 )
				elseif equalSplit[1] == 'popup-list' then
					popupOptions.list = table.concat( equalSplit, '=', 2 )
					if args['noregisterimages'] == nil then
					    -- Only register dependency if location is not Commons
						local location = args.location and string.lower(args.location) or ""
					    if location ~= "commons" and location ~= "" then
					        -- Register this as a dependency so that this page shows up as using all the images on the list page
					        frame:expandTemplate{ title = ':' .. table.concat( equalSplit, '=', 2 ) }
					    end
					end
				else
					galleryRow = galleryRow .. part .. '|'
				end

			end
		end
		if string.sub( galleryRow, -1 ) == '|' then
			galleryRow = string.sub( galleryRow, 1, -2 )
		end
		galleryContents = galleryContents .. galleryRow .. "\n"
		optionsArray[#optionsArray+1] = popupOptions
	end
	return tostring( mw.html.create( 'div' )
		:attr( 'class', 'OWIDSlider' )
		:attr( 'data-owidslider-config', mw.text.jsonEncode( optionsArray ) )
		:wikitext( frame:extensionTag( 'gallery', galleryContents, galleryArgs ) )
		) .. captionText .. '[[Category:Pages using gadget owidslider]]'
end


return p