classdef SnoreMonitor < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                     matlab.ui.Figure
        GridLayout                   matlab.ui.container.GridLayout
        LeftPanel                    matlab.ui.container.Panel
        RecordButton                 matlab.ui.control.Button
        StopButton                   matlab.ui.control.Button
        LoadFileButton               matlab.ui.control.Button
        NofileloadedLabel            matlab.ui.control.Label
        NorecordingdetectedLabel     matlab.ui.control.Label
        StatusLabel                  matlab.ui.control.Label
        FileselectedLabel            matlab.ui.control.Label
        Switch                       matlab.ui.control.Switch
        PlotButton                   matlab.ui.control.Button
        Knob                         matlab.ui.control.DiscreteKnob
        Lamp                         matlab.ui.control.Lamp
        SaveRecordingButton          matlab.ui.control.Button
        RightPanel                   matlab.ui.container.Panel
        NumberofsnoresdetectedLabel  matlab.ui.control.Label
        TotaltimesleepingLabel       matlab.ui.control.Label
        TimespentsnoringLabel        matlab.ui.control.Label
        oftimespentsnoringLabel      matlab.ui.control.Label
        ClearPlotButton              matlab.ui.control.Button
        QuietSnoresLabel             matlab.ui.control.Label
        AverageSnoresLabel           matlab.ui.control.Label
        LoudSnoresLabel              matlab.ui.control.Label
        UIAxes                       matlab.ui.control.UIAxes
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: PlotButton
        function PlotButtonPushed(app, event)
            global recObj
            global fileName
            global filePath
            global fileBool
            global recBool
            axesreset();
            plottype = string(app.Switch.Value);                                       %Gets value of whether the user wants to plot a file or a live recording
            if plottype == "File"
                if fileBool == 2                                                       %Check to see if file is selected correctly
                    app.FileselectedLabel.Text = 'Analysing';                          %Updates Status
                    [audioIn, fs] = audioread(strcat(filePath, fileName));             %Reads in audio file with audioreader based on filepath and name selected using Load File
                    sample = process(audioIn, fs);                                     %Applies pre-processing techniques
                    fs = 16e3;                                                         %Sets updated sampling rate after pre-processing
                    plotcategory(sample, fs)                                           %Calls on all methods to plot information regarding snoring
                    app.FileselectedLabel.Text = 'Analysis Complete';                  %Updates status
                else
                    axesreset();
                    app.FileselectedLabel.Text = 'Incorrect plot';                     %Error handling
                end    
            end
            
            
            if plottype == "Recording"
                if recBool == 3                                                        %Check to see if recording is selected correctly
                    app.FileselectedLabel.Text = 'Analysing';                          %Updates Status
                    audioIn = getaudiodata(recObj);                                    %Reads audiodata from recorder object
                    fs = 16e3;
                    sample = process(audioIn, fs);                                     %Applies pre-processing techniques
                    plotcategory(sample, fs)                                           %Calls on all methods to plot information regarding snoring
                    app.FileselectedLabel.Text = 'Analysis Complete';                  %Updates status
                else
                    axesreset();
                    app.FileselectedLabel.Text = 'Incorrect plot';                     %Error handling
                end
            end

            
                
            function axesreset()                                                       %Resets graph axes to empty/default
                cla(app.UIAxes, "reset")
                app.UIAxes.YTick = [];
                app.UIAxes.XLabel.String = 'Time (minutes)';
                app.UIAxes.YLabel.String = '';
                app.UIAxes.FontWeight = 'bold';
                app.UIAxes.Title.String = 'Snoring events';
                app.NumberofsnoresdetectedLabel.Text = 'Number of snores detected:';
                app.TotaltimesleepingLabel.Text = 'Total time sleeping:';
                app.TimespentsnoringLabel.Text = 'Time spent snoring:';
                app.oftimespentsnoringLabel.Text = '% of time spent snoring:';
            end
            
            
            function resampled = process(audioIn, fs)
                targetFs = 16e3;
                [p, q] = rat(targetFs/fs);
                audioIn = resample(audioIn(:, 1), p, q);                               %Resamples audio to 16kHz
                weightFilter = weightingFilter('A-weighting','SampleRate', targetFs);
                resampled = weightFilter(audioIn);                                     %Adds A-Weighting to signal for perceived loudness of relevant frequencies to snoring
            end
            
            
            function ROI = getROI(audioIn, fs)                                         %Method that uses built-in MATLAB detectSpeech method to look for possible snoring instances 
                
                %Set Parameters for detectSpeech function to specifically
                %look for isolated snoring instances 
                
                windowDuration = 0.03;                                                 %seconds
                numWindowSamples = round(windowDuration*fs);
                win = hamming(numWindowSamples,'periodic');
                
                percentOverlap = 35;
                overlap = round(numWindowSamples*percentOverlap/100);
                
                mergeDuration = 0.8;
                mergeDist = round(mergeDuration*fs);
                
                ROI = detectSpeech(audioIn, ...                                        %Uses detectSpeech to identify possible regions of interest for snoring events
                    fs, ...
                    "Window",win, ...
                    "OverlapLength",overlap, ...
                    "MergeDistance",mergeDist, ...
                    'Thresholds', [1 9e-2]);
                
            end
            
            
            function time = getTime(samples, fs)                                       %Gives intrest region segments in seconds
                prealloc = zeros(size(samples,1), 1);
                for i=1:size(samples, 1)
                    prealloc(i, 1) = (samples(i,2)-samples(i,1))/fs;
                end
                time = prealloc;
            end
            
            
            function time = getTotalTime(audioIn, fs)                                  %Gives total time of recording/file
                time = numel(audioIn)/fs;
            end
            
            
            function [TimeSpentSnoring, PercentTimeSnoring, TotalTimeSleeping]  = displaySnoreStats(audioIn, fs)       %Returns time-specific information for snoring for the audio
                idx = getfreqROI(audioIn, fs);
                timestamps = getTime(idx, fs);
                totaltime = getTotalTime(audioIn, fs);
                snoringtime = (sum(timestamps)/totaltime)*100;                         %Calculates snoring percentage

                TimeSpentSnoring = strcat('Time spent snoring: ', ' ', num2str(round(sum(timestamps))), ' seconds.');
                PercentTimeSnoring = strcat('Total % of time spent snoring: ', ' ', num2str(round(snoringtime, 2)), '% ');
                TotalTimeSleeping = strcat('Total time in bed: ', ' ',num2str(round((totaltime)/60, 2)), ' minutes');
            end

                        
            function snoreROI = getsnoreROI(audioIn, fs)                        %Checks events of snoring and filters out anything over/under the thresholds of duration for snoring
                roi = getROI(audioIn, fs);
                snoretime = getTime(roi, fs);
                snoreROI = zeros(size(roi,1), 2);                               %Preallocates a matrix of 0's to the size of input matrix
                for i=1:size(roi,1)
                    if snoretime(i,1)<4 && snoretime(i,1)>0.25                  %If snoring event falls within the threshold, the 0's matrix is input with the sample numbers
                        snoreROI(i, 1) = roi(i,1);
                        snoreROI(i, 2) = roi(i,2);
                    end
                end
                removezero = nonzeros(snoreROI);
                snoreROI = reshape(removezero, (size(removezero, 1))/2, 2);
            end
            
            
            function snoreFreqROI = getfreqROI(audioIn, fs)                      %Checks for peak frequency power and anything over the determined threshold for snoring is discarded 
                idx = getsnoreROI(audioIn, fs);
                for i=1:size(idx, 1)
                    [power, ~] = pspectrum(audioIn(idx(i,1):idx(i,2), 1), fs, 'spectrogram', 'FrequencyLimits', [20, 1500], 'MinThreshold', -72);
                    powsum = sum(power, 2);                                      %Sums all powers by frequency 
                    powsum = db(powsum);                                         %Converts power to decibels
                    [~, value] = max(powsum);
                    if value > 420                                               %If value is over threshold, the detected event of snoring is set to 0 in the matrix and later removed
                        idx(i, 1) = 0;
                        idx(i, 2) = 0;
                    end
                end
                removezero = nonzeros(idx);
                snoreFreqROI = reshape(removezero, (size(removezero, 1))/2, 2);
            end
            
            
            function snorecat = categoriseSnore(audioIn, fs)                                   %Categorieses snoring into 3 different categories depending on dB of the peak power of snoring
                    froi = getfreqROI(audioIn, fs);
                    if size(froi, 1) == 0                                                      %Handles event where no snoring events were detected
                        snorecat = 0;
                    else
                        prealloc = zeros(size(froi,1), 1);                                     %Preallocates 0's matrices to size of detected snoring events
                        prealloc2 = zeros(size(froi,1), 1);
                        signalpower = db(abs(audioIn), 'power');
                        for i=1:size(froi, 1)
                        prealloc(i) = mean(signalpower(froi(i, 1):froi(i, 2)));                %Calculates mean signalpower for each detected event of snoring
                        end
                        avgM = mean(prealloc);                                                 %Calculates overall mean for every snoring event
                        stdS = std(prealloc);                                                  %Calculates overall standard deviation for every snoring even
                        for j=1:size(froi, 1)
                           X = prealloc(j)-avgM; 
                           prealloc2(j) = X/stdS;                                              %Allocates how many standard deviations away from the mean the snore is 
                        end
                        prealloc3 = zeros(size(froi, 1), 1);
                        for k=1:size(prealloc3, 1)                                             %For loop allocates category based on how far from the average mean the mean of the individual snore is 
                            if prealloc2(k) <-0.5
                                prealloc3(k) = 1;
                            elseif prealloc2(k) > 0.5
                                prealloc3(k) = 3;
                            else
                                prealloc3(k) = 2;
                            end
                        snorecat = prealloc3;   
                        end 
                    end
                    
            end
            
            
            
            function [quiet, average, loud] = countsnores(audioIn, fs)                        %Method to display the allocated categories for each snore
                categorisedSnore = categoriseSnore(audioIn, fs);
                prealloc = zeros(3, 1);
                for i=1:size(categorisedSnore, 1)
                    if categorisedSnore(i) == 1
                        prealloc(1) = prealloc(1) + 1;
                    elseif categorisedSnore(i) == 2
                        prealloc(2) = prealloc(2) + 1;
                    elseif categorisedSnore(i) == 3
                        prealloc(3) = prealloc(3) + 1;    
                    end
                end
                quiet = strcat('Quiet Snores: ', num2str(prealloc(1)));
                average = strcat('Average Snores: ', num2str(prealloc(2)));
                loud = strcat('Loud Snores: ', num2str(prealloc(3)));
            end
            
            
            function plotcategory(audioIn, fs)                                                 %Method to plot on axes all/select events of snoring based on user selection
                val = string(app.Knob.Value);                                                  %Gets value from UI Knob to determine which events of snoring to display
                if val == "All Snores"
                    val = 0;
                elseif val == "Quiet Snores"
                    val = 1;
                elseif val == "Average Snores"
                    val = 2;
                elseif val == "Loud Snores"
                    val = 3;
                end
                idx = getfreqROI(audioIn, fs);                                                 %Gets detected snoring events
                categorisedSnore = categoriseSnore(audioIn, fs);
                time=(1/fs)*length(audioIn);                                                   
                t=linspace(0,time/60,length(audioIn));                                         %Calculates time to plot against
                cat3 = zeros(size(audioIn, 1), 1);
                if categorisedSnore == 0                                                       %Handles event in case no events of snoring detected
                    axesreset();
                    app.NumberofsnoresdetectedLabel.Text = 'No snores detected';
                    plot(app.UIAxes, t, abs(audioIn));
                    hold(app.UIAxes, "off");
                    app.UIAxes.YTick = [];
                    app.UIAxes.XLabel.String = 'Time (minutes)';
                    app.UIAxes.YLabel.String = '';
                    app.QuietSnoresLabel.Text = 'Quiet Snores:0 ';
                    app.AverageSnoresLabel.Text = 'Average Snores:0 ';
                    app.LoudSnoresLabel.Text = 'Loud Snores:0 ';
                    
                else
                    for i=1:size(idx, 1)                                                       %Prepares plot based on snore category selected by user
                        if categorisedSnore(i) == val
                            [maxval, maxidx] = max(abs(audioIn(idx(i, 1):idx(i, 2))));
                            cat3(idx(i, 1) + maxidx) = maxval;
                        elseif val == 0
                           [maxval, maxidx] = max(abs(audioIn(idx(i, 1):idx(i, 2))));
                           cat3(idx(i, 1) + maxidx) = maxval;
                        end
                    end
                plot(app.UIAxes, t, (cat3 * 2));                                               %Highlights event of snoring
                hold(app.UIAxes, "on");
                plot(app.UIAxes, t, abs(audioIn));                                             %Plots original audio singal alongside highlighted events of snoring
                hold(app.UIAxes, "off");
                legend(app.UIAxes, 'Snoring');
                app.UIAxes.YTick = [];
                app.UIAxes.XLabel.String = 'Time (minutes)';
                app.UIAxes.YLabel.String = '';
                [timesnored, timesnorepercent, totalsleep] = displaySnoreStats(audioIn, fs);
                [q, a, l] = countsnores(audioIn, fs);                                          %Gets number of snores detected by category
                z = strcat(num2str(size(idx, 1)), ' Events of snoring detected');
                app.NumberofsnoresdetectedLabel.Text = z;
                app.TotaltimesleepingLabel.Text = totalsleep;
                app.TimespentsnoringLabel.Text = timesnored;
                app.oftimespentsnoringLabel.Text = timesnorepercent;
                app.QuietSnoresLabel.Text = q;
                app.AverageSnoresLabel.Text = a;
                app.LoudSnoresLabel.Text = l;
                end
                               
            end
            
            
            
            
            
        end

        % Button pushed function: RecordButton
        function RecordButtonPushed(app, event)
            global recObj                                                                                       %Method for recording live audio 
            global recBool                                                                                      %Value that keeps track of recording status

            if recBool == 2
                app.FileselectedLabel.Text = "Already recording";
            else
                recObj = audiorecorder(16e3, 16, 1) ; %create object
                record(recObj); %start Recording
                recBool = 2;
                app.FileselectedLabel.Text = "Recording";
                app.Lamp.Color = [1.00 0.00 0.00];
            end
        end

        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
            global recObj                                                                                       %Method for stopping recording
            global recBool

            if recBool == 2
                recBool = 3;
                stop(recObj) % Stop
                value = string(app.Switch.Value);
                if value == "File"
                    app.FileselectedLabel.Text = strcat(value, ' selected');
                end
                
                if value == "Recording"
                    app.FileselectedLabel.Text = strcat(value, ' selected');
                end
                app.NorecordingdetectedLabel.Text = 'Recording ready';
                app.Lamp.Color = [0.00 1.00 0.00];
            elseif recBool == 3
                app.FileselectedLabel.Text = 'Currently not recording';                                         %Error handling
            else    
                app.FileselectedLabel.Text = 'No recording detected';
            end
            
        end

        % Button pushed function: ClearPlotButton
        function ClearPlotButtonPushed(app, event)
            cla(app.UIAxes, "reset")                                                                                %Resets graph axes to empty/default
            app.UIAxes.YTick = [];
            app.UIAxes.XLabel.String = 'Time (minutes)';
            app.UIAxes.YLabel.String = '';
            app.UIAxes.FontWeight = 'bold';
            app.UIAxes.Title.String = 'Snoring events';
            app.NumberofsnoresdetectedLabel.Text = 'Number of snores detected:';
            app.TotaltimesleepingLabel.Text = 'Total time sleeping:';
            app.TimespentsnoringLabel.Text = 'Time spent snoring:';
            app.oftimespentsnoringLabel.Text = '% of time spent snoring:';
            app.QuietSnoresLabel.Text = 'Quiet Snores: ';
            app.AverageSnoresLabel.Text = 'Average Snores: ';
            app.LoudSnoresLabel.Text = 'Loud Snores: ';
        end

        % Button pushed function: LoadFileButton
        function LoadFileButtonPushed(app, event)
            global fileName
            global filePath
            global fileBool
            
            [fileName, filePath] = uigetfile(['*.wav;*.ogg;*.flac;' ...                                              %Prompts the user to load in a file           
                '*.au;*.aiff;*.aif;*.aifc;' ...
                '*.mp3;*.m4a;*mp4']);
            if isequal(fileName, 0)                                                                                  %Check to see if the user pressed cancel 
                fileBool = 0;
                app.FileselectedLabel.Text = 'User selected Cancel';                                                 %Sets status to user selecting cancel
            else
                fileBool = 2;
                loaded = strcat(fileName, " Loaded");                                                                
                app.NofileloadedLabel.Text = loaded;                                                                 %Sets status to the filer user has loaded 
            end
            
        end

        % Value changed function: Switch
        function SwitchValueChanged(app, event)
            value = string(app.Switch.Value);                                                                        %Method to update status based on file/recording selected
            if value == "File"
                app.FileselectedLabel.Text = strcat(value, ' selected');
            end
            
            if value == "Recording"
                app.FileselectedLabel.Text = strcat(value, ' selected');
            end
            
        end

        % Button pushed function: SaveRecordingButton
        function SaveRecordingButtonPushed(app, event)
            global recBool                                                                                           %Method to save live recording as .wav file
            global recObj
            
            if recBool == 3
                [nfname,npath]=uiputfile('.m4a','Save sound','new_sound.m4a');
                if isequal(nfname,0) || isequal(npath,0)
                    app.FileselectedLabel.Text = 'User cancelled save';                 % Error handling for user selecting cancel
                else
                   filename = strcat(npath, nfname);
                   audioIn = getaudiodata(recObj);
                   fs = 16e3;
                   sample = saveprocess(audioIn, fs);
                   audiowrite(filename, sample , 44.1e3)
                   app.FileselectedLabel.Text = 'File saved';
                end
                
            else
                app.FileselectedLabel.Text = 'No recording detected';
            end
            
            
            function resampled = saveprocess(audioIn, fs)                               %Seperate method for processing before saving due to MATLAB compatibility issues
                targetFs = 44.1e3;
                [p, q] = rat(targetFs/fs);
                resampled = resample(audioIn(:, 1), p, q);                              %Resamples audio to 44.1kHz
            end
            
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 2x1 grid
                app.GridLayout.RowHeight = {480, 480};
                app.GridLayout.ColumnWidth = {'1x'};
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 1;
            else
                % Change to a 1x2 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {220, '1x'};
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 2;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 647 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {220, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create RecordButton
            app.RecordButton = uibutton(app.LeftPanel, 'push');
            app.RecordButton.ButtonPushedFcn = createCallbackFcn(app, @RecordButtonPushed, true);
            app.RecordButton.Position = [46 112 100 22];
            app.RecordButton.Text = 'Record';

            % Create StopButton
            app.StopButton = uibutton(app.LeftPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.Position = [45 79 100 22];
            app.StopButton.Text = 'Stop';

            % Create LoadFileButton
            app.LoadFileButton = uibutton(app.LeftPanel, 'push');
            app.LoadFileButton.ButtonPushedFcn = createCallbackFcn(app, @LoadFileButtonPushed, true);
            app.LoadFileButton.Position = [46 8 100 22];
            app.LoadFileButton.Text = 'Load File';

            % Create NofileloadedLabel
            app.NofileloadedLabel = uilabel(app.LeftPanel);
            app.NofileloadedLabel.FontWeight = 'bold';
            app.NofileloadedLabel.FontColor = [0.149 0.149 0.149];
            app.NofileloadedLabel.Position = [16 354 198 22];
            app.NofileloadedLabel.Text = 'No file loaded';

            % Create NorecordingdetectedLabel
            app.NorecordingdetectedLabel = uilabel(app.LeftPanel);
            app.NorecordingdetectedLabel.FontWeight = 'bold';
            app.NorecordingdetectedLabel.FontColor = [0.149 0.149 0.149];
            app.NorecordingdetectedLabel.Position = [16 388 198 27];
            app.NorecordingdetectedLabel.Text = 'No recording detected';

            % Create StatusLabel
            app.StatusLabel = uilabel(app.LeftPanel);
            app.StatusLabel.Position = [16 445 46 22];
            app.StatusLabel.Text = 'Status: ';

            % Create FileselectedLabel
            app.FileselectedLabel = uilabel(app.LeftPanel);
            app.FileselectedLabel.FontWeight = 'bold';
            app.FileselectedLabel.Position = [16 424 148 22];
            app.FileselectedLabel.Text = 'File selected';

            % Create Switch
            app.Switch = uiswitch(app.LeftPanel, 'slider');
            app.Switch.Items = {'File', 'Recording'};
            app.Switch.ValueChangedFcn = createCallbackFcn(app, @SwitchValueChanged, true);
            app.Switch.FontWeight = 'bold';
            app.Switch.Position = [64 311 63 28];
            app.Switch.Value = 'File';

            % Create PlotButton
            app.PlotButton = uibutton(app.LeftPanel, 'push');
            app.PlotButton.ButtonPushedFcn = createCallbackFcn(app, @PlotButtonPushed, true);
            app.PlotButton.FontWeight = 'bold';
            app.PlotButton.Position = [45 159 100 22];
            app.PlotButton.Text = 'Plot';

            % Create Knob
            app.Knob = uiknob(app.LeftPanel, 'discrete');
            app.Knob.Items = {'All Snores', 'Quiet Snores', 'Average Snores', 'Loud Snores'};
            app.Knob.Position = [68 196 59 59];
            app.Knob.Value = 'All Snores';

            % Create Lamp
            app.Lamp = uilamp(app.LeftPanel);
            app.Lamp.Position = [16 113 20 20];
            app.Lamp.Color = [1 1 1];

            % Create SaveRecordingButton
            app.SaveRecordingButton = uibutton(app.LeftPanel, 'push');
            app.SaveRecordingButton.ButtonPushedFcn = createCallbackFcn(app, @SaveRecordingButtonPushed, true);
            app.SaveRecordingButton.Position = [46 45 101 22];
            app.SaveRecordingButton.Text = 'Save Recording';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create NumberofsnoresdetectedLabel
            app.NumberofsnoresdetectedLabel = uilabel(app.RightPanel);
            app.NumberofsnoresdetectedLabel.FontWeight = 'bold';
            app.NumberofsnoresdetectedLabel.Position = [6 79 402 22];
            app.NumberofsnoresdetectedLabel.Text = 'Number of snores detected:';

            % Create TotaltimesleepingLabel
            app.TotaltimesleepingLabel = uilabel(app.RightPanel);
            app.TotaltimesleepingLabel.FontWeight = 'bold';
            app.TotaltimesleepingLabel.Position = [6 58 402 22];
            app.TotaltimesleepingLabel.Text = 'Total time sleeping:';

            % Create TimespentsnoringLabel
            app.TimespentsnoringLabel = uilabel(app.RightPanel);
            app.TimespentsnoringLabel.FontWeight = 'bold';
            app.TimespentsnoringLabel.Position = [6 37 402 22];
            app.TimespentsnoringLabel.Text = 'Time spent snoring:';

            % Create oftimespentsnoringLabel
            app.oftimespentsnoringLabel = uilabel(app.RightPanel);
            app.oftimespentsnoringLabel.FontWeight = 'bold';
            app.oftimespentsnoringLabel.Position = [6 16 383 22];
            app.oftimespentsnoringLabel.Text = '% of time spent snoring:';

            % Create ClearPlotButton
            app.ClearPlotButton = uibutton(app.RightPanel, 'push');
            app.ClearPlotButton.ButtonPushedFcn = createCallbackFcn(app, @ClearPlotButtonPushed, true);
            app.ClearPlotButton.Position = [319 79 100 22];
            app.ClearPlotButton.Text = 'Clear Plot';

            % Create QuietSnoresLabel
            app.QuietSnoresLabel = uilabel(app.RightPanel);
            app.QuietSnoresLabel.FontWeight = 'bold';
            app.QuietSnoresLabel.Position = [270 58 121 22];
            app.QuietSnoresLabel.Text = 'Quiet Snores: ';

            % Create AverageSnoresLabel
            app.AverageSnoresLabel = uilabel(app.RightPanel);
            app.AverageSnoresLabel.FontWeight = 'bold';
            app.AverageSnoresLabel.Position = [269 37 121 22];
            app.AverageSnoresLabel.Text = 'Average Snores: ';

            % Create LoudSnoresLabel
            app.LoudSnoresLabel = uilabel(app.RightPanel);
            app.LoudSnoresLabel.FontWeight = 'bold';
            app.LoudSnoresLabel.Position = [269 16 121 22];
            app.LoudSnoresLabel.Text = 'Loud Snores: ';

            % Create UIAxes
            app.UIAxes = uiaxes(app.RightPanel);
            title(app.UIAxes, 'Snoring events')
            xlabel(app.UIAxes, 'Time (minutes)')
            app.UIAxes.PlotBoxAspectRatio = [1.23003194888179 1 1];
            app.UIAxes.FontWeight = 'bold';
            app.UIAxes.YTick = [];
            app.UIAxes.NextPlot = 'add';
            app.UIAxes.Position = [6 112 413 367];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SnoreMonitor

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end