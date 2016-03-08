classdef Viewer < handle
    
    properties
        %Handles
        fig
        tabGroup
        Settings
        tabDC
        tabPlotEEG
        
        
        chansToPlot = 1
        filtOrder = 1
        filtFreq = 10
        filtBW = 5
        Fs = 500
        filtercoeffs
        DataFilt
        DataDemod
        
    end
    
    
    
    methods
        
        function handles = Viewer(Acti)
            
            %Initialise GUI
            handles.initGUI();
            
            %Define listeners to respond to GUI/Data events
            addlistener (Acti, 'EEG_packet', 'PostSet', @(o,e) handles.onNewData(handles,e.AffectedObject));
            %Populate list box with channels names on start
            addlistener (Acti, 'channelNames', 'PostSet', @(o,e) handles.onPropChange(handles,e.AffectedObject));
        end
        
        function initGUI(self)
            
            %Load layout from GUIDE figure
            hFig = hgload('fig_layout.fig');
            
            %Define tab grounp
            %Can't create tabs using GUIDE, so get tabs location from 'helper' panel
            %object.
            hPlotPanel = findobj(hFig,'tag','Plotpanel');
            hTabGroupPlot = uitabgroup('Parent',hFig, 'Units', get(hPlotPanel,'Units'),'Position',get(hPlotPanel,'Position'));
            
            %Settings panel
            
            hSettingsPanel = findobj(hFig, 'tag' ,'settingsPanel');
            
            lblHost =  findobj(hFig, 'tag' , 'lblHost');
            editHostIP =  findobj(hFig, 'tag' , 'editHostIP');
            btConnect =  findobj(hFig, 'tag' , 'btConnect');
            lblRange =  findobj(hFig, 'tag' , 'lblRange');
            editRange =  findobj(hFig, 'tag' , 'editRange');
            chanSelect =  findobj(hFig, 'tag' , 'lstChannels');
            lblTime = findobj(hFig,'tag','lblTime');
            editTime = findobj(hFig,'tag','editTime');
            chkFilter = findobj(hFig,'tag','chkFilter');
            chkDemod  = findobj(hFig,'tag','chkDemod');
            lblFiltOrder = findobj(hFig,'tag','lblFiltOrder');
            popFiltOrder = findobj(hFig,'tag','popFiltOrder');
            lblFiltFreq = findobj(hFig,'tag','lblFiltFreq');
            editFiltFreq = findobj(hFig,'tag','editFiltFreq');
            lblFiltBW = findobj(hFig,'tag','lblFiltBW');
            editFiltBW = findobj(hFig,'tag','editFiltBW');
            lblFs = findobj(hFig,'tag','lblFs');
            
            handles_Settings = struct(  'HostIP',editHostIP, 'btConnect',btConnect, 'Range',editRange,...
                'lstChannels',chanSelect,'Time',editTime,'chkFilter',chkFilter, 'chkDemod',chkDemod,...
                'FiltOrder',popFiltOrder','FiltFreq',editFiltFreq, 'FiltBW',editFiltBW, 'lblFs',lblFs);
            
            
            hTabPlotEEG = uitab('Parent', hTabGroupPlot, 'Title', 'Default');
            
            % construct the axes to display time and frequency domain data
            % Axes are defined as children of panel object in GUIDE, need to change
            % this to the tab being used.
            axTime = findobj(hFig,'tag', 'axTime');
            set(axTime,'Parent',hTabPlotEEG);
            axFreq = findobj(hFig,'tag', 'axFreq');
            set(axFreq,'Parent',hTabPlotEEG);
            
            
            %Set inital y-axis range
            hTime = plot(axTime,(1:10)/10);
            hFreq = plot(axFreq,(1:10)/10);
            yrange = 1e3*str2num(get(editRange,'String'));
            
            set(axTime,'YLim',[-yrange yrange]);
            xlabel(axTime,'Time (s)');
            ylabel(axTime, '(uV)');
            
            handles_TabPlotEEG = struct('tab',hTabPlotEEG, 'axTime',axTime, 'axFreq',axFreq, 'plotTime',hTime, 'plotFreq',hFreq);
            
            % *** DC Offset Tab ***
            hTabDC = uitab('Parent', hTabGroupPlot, 'Title', 'DC Offset');
            
            
            axDC = findobj(hFig,'tag', 'axDC');
            set(axDC,'Parent',hTabDC);
            hBar = bar(axDC,1:16,1:16);
             xlabel(axDC,'Channel');
             ylabel(axDC, 'DC Offset (uV)');
            set(axDC,'YLim',[-yrange yrange]);
            
            
            
            handles_tabDC = struct('tab',hTabDC, 'ax',axDC, 'bar',hBar);
            
            % Assign the GUI a name to appear in the window title.
            set(hFig,'Name','Brain Vision RDA Client for MATLAB')
            % Move the GUI to the center of the screen.
            movegui(hFig,'center')
            % Make the GUI visible.
            set(hFig,'Visible','on');
            
            self.fig = hFig;
            self.tabGroup = hTabGroupPlot;
            self.Settings = handles_Settings;
            self.tabDC = handles_tabDC;
            self.tabPlotEEG = handles_TabPlotEEG;
            
        end
        
        
        
        function onNewData(self,handles,obj)
            
            %Update DC offsets
            obj.V_DCs = mean(obj.EEG_packet,2);
            
            
            %Check if filt/demod tick boxes are active
            if (get(handles.Settings.chkFilter,'Value'))
                
                obj.EEG_packet = filtfilt(handles.filtercoeffs.b, handles.filtercoeffs.a, double(obj.EEG_packet));
            end
            
            if (get(handles.Settings.chkDemod,'Value'))
                obj.EEG_packet = abs(hilbert(obj.EEG_packet));
            end
            
            %Append EEG_packet to data buffer
            
            siz_EEG = size(obj.EEG_packet);
            obj.data_buf_dims = size(obj.data_buf);
            newdata_index = (obj.data_buf_dims(2)+1):(obj.data_buf_dims(2)+siz_EEG(2));
            obj.data_buf(:,newdata_index)=obj.EEG_packet;
            
            % If data buffer is longer than len_data_buf, reset buffer
            % and display filt/demod data
            obj.data_buf_dims = size(obj.data_buf);
            if obj.data_buf_dims(2) > 1e6 * obj.len_data_buf / obj.props.samplingInterval
                obj.data_buf = [];
            end
            
            
            %Only update graph for active tab
            active_tab = get(handles.tabGroup,'SelectedIndex');
            switch active_tab
                case 1
                    self.updateEEGPlot(handles,obj)
                    
                case 2
                    self.updateDCOffset(handles,obj)
            end
        end
        
        function updateEEGPlot(self,handles,obj)
            %Update this to plot whichever channel(s) are selected
            
            obj.data_buf_dims = size(obj.data_buf);
            
            downsample = 50;
            
            if (obj.data_buf_dims) %Don't try to plot if empty
                set(handles.tabPlotEEG.plotTime,'XData', (1:downsample:obj.data_buf_dims(2)).*1e-6.*obj.props.samplingInterval)
                set(handles.tabPlotEEG.plotTime,'YData',obj.data_buf(self.chansToPlot,1:downsample:end))
            end
        end
        
        
        
        function updateDCOffset(self,handles,obj)
            
            set(handles.tabDC.bar,'YData',obj.V_DCs);
            
        end
        
        
        
        function onPropChange(self,handles,obj)
            % Populate list box with channel names
            set(handles.Settings.lstChannels,'String',obj.props.channelNames);
            Fs = 1e6./obj.props.samplingInterval;
            set(handles.Settings.lblFs,'String',['Fs: ' num2str(Fs) 'Hz']);
        end
        
    end
    
end