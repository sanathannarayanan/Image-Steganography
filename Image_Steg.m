clc;    % Clear the command window.
close all;  % Close all figures (except those of imtool.)
clear;  % Erase all existing variables. Or clearvars if you want.
workspace;  % Make sure the workspace panel is showing.
format long g;
format compact;
fontSize = 20;
% Check that user has the Image Processing Toolbox installed.
hasIPT = license('test', 'image_toolbox');   % license('test','Statistics_toolbox'), license('test','Signal_toolbox')
if ~hasIPT
	% User does not have the toolbox installed.
	message = sprintf('Sorry, but you do not seem to have the Image Processing Toolbox.\nDo you want to try to continue anyway?');
	reply = questdlg(message, 'Toolbox missing', 'Yes', 'No', 'Yes');
	if strcmpi(reply, 'No')
		% User said No, so exit.
		return;
	end
end
%===============================================================================
% Get the name of the cover image the user wants to use.
% Let the user select from a list of all the demo images that ship with the Image Processing Toolbox.
folder = fileparts(which('cameraman.tif')); % Determine where demo folder is (works with all versions).
files = [dir(fullfile(folder,'*.TIF')); dir(fullfile(folder,'*.PNG')); dir(fullfile(folder,'*.jpg'))];
for k = 1 : length(files)
% 	fprintf('%d: %s\n', k, files(k).name);
	[~, baseFileName, extension] = fileparts(files(k).name);
	ca{k} = baseFileName;  % cell array
end
% Sort alphabetically
[ca, sortOrder] = sortrows(ca');
files = files(sortOrder); % Sort files the same way we did for the cell array.
% celldisp(ca);
button = menu('Use which gray scale demo image?', ca); % Display all image file names in a popup menu.
if button == 0
	return; % Use clicked the white x in the red square in the upper right of the title bar - not a button.
end
% Get the base filename.
baseFileName = files(button).name; % Assign the one on the button that they clicked on.
% Get the full filename, with path prepended.
fullFileName = fullfile(folder, baseFileName);
%===============================================================================
% Read in a standard MATLAB gray scale demo image and display it.
% Check if file exists.
if ~exist(fullFileName, 'file')
	% File doesn't exist -- didn't find it there.  Check the search path for it.
	fullFileNameOnSearchPath = baseFileName; % No path this time.
	if ~exist(fullFileNameOnSearchPath, 'file')
		% Still didn't find it.  Alert user.
		errorMessage = sprintf('Error: %s does not exist in the search path folders.', fullFileName);
		uiwait(warndlg(errorMessage));
		return;
	end
end
[grayCoverImage, storedColorMap] = imread(fullFileName);
% This is the "cover" image - the readily apparent image that the viewer will see.
% This is the image that will "hide" the string.  In other words, our string will be hidden in this image
% so that all the viewer will notice is this cover image, and will not notice the text string.
% Get the dimensions of the image.  
% numberOfColorBands should be = 1.
[rows, columns, numberOfColorChannels] = size(grayCoverImage);
if numberOfColorChannels > 1
	% It's not really gray scale like we expected - it's color.
	% Convert it to gray scale by taking only the green channel.
	grayCoverImage = grayCoverImage(:, :, 2); % Take green channel.
elseif ~isempty(storedColorMap)
	% There's a colormap, so it's an indexed image, not a grayscale image.
	% Apply the color map to turn it into an RGB image.
	grayCoverImage = ind2rgb(grayCoverImage, storedColorMap);
	% Now turn it into a gray scale image.
	grayCoverImage = uint8(255 * mat2gray(rgb2gray(grayCoverImage)));
end
[rows, columns, numberOfColorChannels] = size(grayCoverImage); % Update.  Only would possibly change, and that's if the original image was RGB or indexed.
% Display the image.
hFig = figure;
subplot(1, 2, 1);
imshow(grayCoverImage, []);
axis on;
caption = sprintf('The Original Grayscale Image\nThe "Cover" Image.');
title(caption, 'FontSize', fontSize, 'Interpreter', 'None');
% Set up figure properties:
% Enlarge figure to full screen.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
% Get rid of tool bar and pulldown menus that are along top of figure.
set(gcf, 'Toolbar', 'none', 'Menu', 'none');
% Give a name to the title bar.
set(gcf, 'Name', 'Image Steganography by SANATHAN NARAYANAN', 'NumberTitle', 'Off') 
%===============================================================================
% Get the string the user wants to hide:
hiddenString = 'This is your sample hidden string.';
% Ask user for a string.
defaultValue = hiddenString;
titleBar = 'Enter the string you want to hide';
userPrompt = 'Enter the string you want to hide';
caUserInput = inputdlg(userPrompt, titleBar, [1, length(userPrompt) + 75], {num2str(defaultValue)});
if isempty(caUserInput)
	% Bail out if they clicked Cancel.
	close(hFig);
	return;
end; 
% Convert cell to character.
whos caUserInput;
hiddenString = cell2mat(caUserInput); % Could also use char() instead of cell2mat().
whos hiddenString;
%===============================================================================
% Get the bit plane the user wants to use to hide the message in.
% The lowest, least significant bit is numbered 1, and the highest allowable bit plane is 8.
% Values of 5 or more may allow the presence of a hidden text be noticeable in the image in the left column.
% Note: there is really no reason to use any other bit plane than the lowest one, unless you have more text than can fit in the image but then
% you'd have to use multiple bit planes instead of just one.  This is a very unlikely situation.
% Ask user for what bitplane they want to use.
defaultValue = 1;
titleBar = 'Enter the bit plane.';
userPrompt = 'Enter the bit plane you want to use (1 through 8)';
caUserInput = inputdlg(userPrompt, titleBar, [1, length(userPrompt) + 15], {num2str(defaultValue)});
if isempty(caUserInput),return,end; % Bail out if they clicked Cancel.
% Round to nearest integer in case they entered a floating point number.
integerValue = round(str2double(cell2mat(caUserInput)));
% Check for a valid integer.
if isnan(integerValue)
    % They didn't enter a number.  
    % They clicked Cancel, or entered a character, symbols, or something else not allowed.
    integerValue = defaultValue;
    message = sprintf('I said it had to be an integer.\nI will use %d and continue.', integerValue);
    uiwait(warndlg(message));
end
bitToSet = integerValue; % Normal value is 1.
if bitToSet < 1
	bitToSet = 1;
elseif bitToSet > 8
	bitToSet = 8;
end
%===============================================================================
% Encode length of the string the user wants to use into the first 4 characters of the string:
% The first thing we need to do is to determine the number of characters in the string.
% Then we need to make some digits at the beginning of the string the length of the string
% so that we know how many pixels we need to read from the image when we try
% to extract the string from the image.  For example, if the string is "Hello World", that is 11 characters long
% Let's give 4 digits to the length of the string so we can handle up to strings of length 9999.
% So for our example string of 11 characters, we'd prepend 0011 to the string, and the new string would be
% "0011Hello World".  What we do is to first extract 4 characters from the image, and convert it to a number,
% 11 in our example.  Then we know that we need to read 11 additional characters, not the whole image.  This saves time.
hiddenString = sprintf('%4.4d%s', length(hiddenString), hiddenString)
% Convert into the string's ASCII codes by using a trick of subtracting zero.
asciiValues = hiddenString - 0
% asciiValues = int32(hiddenString); % This also works.
% asciiValues = uint8(hiddenString); % This also works
stringLength = length(asciiValues);
%===============================================================================
% Make sure image is big enough to hold string.  Truncate string if necessary.
% Make sure the length of the string is less than the number of elements in the image divided by 7
% because we will encode each bit into the lowest bit of the pixel and there are 7 bits per ASCII letter/character.
numPixelsInImage = numel(grayCoverImage);
bitsPerLetter = 7;	% For ASCII, this is 7.
numPixelsNeededForString = stringLength * bitsPerLetter;
if numPixelsNeededForString > numPixelsInImage
	warningMessage = sprintf('Your message is %d characters long.\nThis will require %d pixels,\nhowever your image has only %d pixels.\nI will use just the first %d characters.',...
		stringLength, numPixelsNeededForString, numPixelsInImage, numPixelsInImage);
	uiwait(warndlg(warningMessage));
	asciiValues = asciiValues(1:floor(numPixelsInImage/bitsPerLetter));
	stringLength = length(asciiValues);	
	numPixelsNeededForString = stringLength * bitsPerLetter;
else
	message = sprintf('Your message is %d characters long.\nThis will require %d * %d = %d pixels,\nYour image has %d pixels so it will fit.',...
		stringLength, stringLength, bitsPerLetter, numPixelsNeededForString, numPixelsInImage);
	fprintf('%s\n', message);
	uiwait(helpdlg(message));
end
%===============================================================================
% Convert string to binary digits, zeros and ones.
% Convert from ASCII values in the range 0-255 to binary values of 0 and 1.
binaryAsciiString = dec2bin(asciiValues)'
whos binaryAsciiString
% Transpose it and string them all together into a row vector.
% This is the string we want to hide.  Each bit will go into one pixel.
binaryAsciiString = binaryAsciiString(:)'
% When you see it in the command window, the characters' ASCII codes will be vertical.  Each character is one column.
%===========================================================================================================
% HERE IS WHERE WE ACTUALLY HIDE THE TEXT MESSAGE
% Make a copy of our image because most pixels will be the same.  We only need to change those pixels that hold our string.
stegoImage = grayCoverImage;
% First set all bits to 0;
stegoImage(1:numPixelsNeededForString) = bitset(stegoImage(1:numPixelsNeededForString), bitToSet, 0);
% Now set only the pixels that are 1 in the string, to 1 in the gray scale image.
% First find, the linear indexes which have a 1 value in them.
oneIndexes = find(binaryAsciiString == '1'); 
% Then set only those indexes to 1 in the specified bit plane.
stegoImage(oneIndexes) = bitset(stegoImage(oneIndexes), bitToSet, 1);
%===========================================================================================================
%===========================================================================================================
% Now stegoImage holds our string, hidden in the upper left column(s).
% Display the steganography image.
subplot(1, 2, 2);
imshow(stegoImage, []);
axis on;
caption = sprintf('Image with your string hidden\nin the upper left column.');
if bitToSet < 5
	caption = sprintf('%s\n(You will not be able to notice it.)', caption);
end
title(caption, 'FontSize', fontSize, 'Interpreter', 'None');
%===========================================================================================================
% HERE IS WHERE WE RECOVER THE HIDDEN TEXT MESSAGE FROM THE IMAGE.
% First we need to know how long the string is.  We encoded the string length into the first 4 characters of the string.
% Let's get those first 4 characters so we'll know how long the rest of the string is.
numPixelsNeededForString = 4 * bitsPerLetter;
retrievedBits = bitget(stegoImage(1:numPixelsNeededForString), bitToSet)
letterCount = 1;
for k = 1 : bitsPerLetter : numPixelsNeededForString
	% Get the binary bits for this one character.
	thisString = retrievedBits(k:(k+bitsPerLetter-1));
	% Turn it from a binary string into an ASCII number (integer) and then finally into a character/letter.
	thisChar = char(bin2dec(num2str(thisString)));
	% Store this letter as we build up the recovered string.
	recoveredString(letterCount) = thisChar;
	letterCount = letterCount + 1;
end
stringLength = str2double(recoveredString) + 4;
numPixelsNeededForString = stringLength * bitsPerLetter;
% Now we know that the length and string will be all contained in numPixelsNeededForString pixels.
% Now try to extract the original hidden string, reading only as many pixels as we need to (what we learned in the first 4 characters).
retrievedBits = bitget(stegoImage(1:numPixelsNeededForString), bitToSet)
% Reshape into a 2-D array
retrievedAsciiTable = reshape(retrievedBits, [bitsPerLetter, numPixelsNeededForString/bitsPerLetter])
letterCount = 1;
nextPixel = 4 * bitsPerLetter + 1; % Skip past the first 4 characters that had the length in them.
for k = nextPixel : bitsPerLetter : numPixelsNeededForString
	% Get the binary bits for this one character.
	thisString = retrievedBits(k:(k+bitsPerLetter-1));
	% Turn it from a binary string into an ASCII number (integer) and then finally into a character/letter.
	thisChar = char(bin2dec(num2str(thisString)));
	% Store this letter as we build up the recovered string.
	recoveredString(letterCount) = thisChar;
	letterCount = letterCount + 1;
end
%===========================================================================================================
% Now recoveredString contains the hidden, recovered string (without the first 4 characters which were the length of the string).
% Display a popup message to the user with the recovered string.
message = sprintf('The recovered string = \n%s\n', recoveredString);
fprintf('%s\n', message); % Also print to command window.
uiwait(helpdlg(message));