#!/usr/bin/perl

use strict;
use warnings;
use POSIX;
use Device::USB::PCSensor::HidTEMPer;
use Data::Dumper;
use Statistics::Basic qw(:all);


#** @var $fh default fileHandler
my $fh;
#** @var $debug debug flag
my $debug=1;
#** @var $LogPath debug log path
my $LogPath="/tmp/sensor-debug";

#** @function public  getDHT11($gpio)
# @brief get DHT11 temperature and humidity
# @param requiered $gpio $_[0] GPIO PIN where sensor is connected
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getDHT11{
	#** @var @curTemp stores current temperature
	my $curTemp;
	#** @var $curHum stores current humidity
	my $curHum;
        #** @var @temp multi purporage storage
        my @temp;

        if($debug >= 3){
                print "\tgetDHT11\n";
        }

        if( !(-r '/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT') ){
                return ('U', 'U');
        }

        @temp = `/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT 11 $_[0]`;
	
	if( !(defined $temp[2]) ){
		return ('U', 'U');
	}

        if( !($temp[2] =~ m/^Temp\ =\ (.*)\*C/) ){
                return ('U', 'U');
        }
        else{  
                $curTemp = $1;
        }

	if( !($temp[2] =~ m/Hum\ =\ (.*)\ \%/) ){
                return ('U', 'U');
        }
        else{
                $curHum = $1;
        }

	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp $curHum >> $LogPath/dht11_$_[0]");
		if($debug >=2){
			print "\t\tgetDHT11 $curTemp $curHum\n";
		}
	}
	
	return ($curTemp, $curHum);
}


#** @function public  getHidTEMPer()
# @brief get HidTEMPer temperature 
# @todo add UniqID if possible need another sensor!
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getHidTEMPer{
	#** @var @curTemp stores current temperature
	my $curTemp;
	#** @var $temper stores HidTEMPer object
	my $temper;
	#** @var $sensor stores HidTEMPer sensor
	my $sensor;

        if($debug >= 3){
                print "\tgetHidTEMPer\n";
        }

	$temper = Device::USB::PCSensor::HidTEMPer->new();

	$sensor = $temper->device();

	if(defined $sensor->internal() ){
		$curTemp = $sensor->internal()->celsius();
	}
	else{
		return 'U';
	}

	if($curTemp < -40 || $curTemp > 120){	# || $curTemp[0] == 53.171875){
        return 'U';
    }

	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp >> $LogPath//hidtemper");
		if($debug >=2){
			print "\t\tgetHidTEMPer $curTemp\n";
		}
	}
	return $curTemp;
}

#** @function public bcm2708Temp ()
# @brief get bcm2708 temperature 
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getBCM2708{
        #** @var @curTemp stores current temperature
	my $curTemp;
	#** @var @temp multi purporage storage
	my @temp;
	
        if($debug >= 3){
                print "\tgetBCM2708\n";
        }

        if( !(-r '/opt/vc/bin/vcgencmd') ){
                return 'U';
        }

        @temp = `/opt/vc/bin/vcgencmd measure_temp`;
        if( !($temp[0] =~ m/^temp=(.*)'C$/) ){
                return 'U';
        }
        else{
                $curTemp = $1;
        }

	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp >> $LogPath/bcm2708");
		if($debug >=2){
			print "\t\tgetBCM2708 $curTemp\n";
		}
	}
        return $curTemp;
}


#** @function public getTempDS1820 ($ID)
# @brief get DS1820 temperature 
# @param requiered $ID $_[0] ID of Sensor
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub getTempDS1820{
	#** @var @curTemp stores current temperature
	my $curTemp;
	#** @var @temp multi purporage storage
	my @temp;
	
	if($debug >= 3){
		print "\tgetTempDS1820\n";
	}

	open($fh, "<", "/sys/bus/w1/devices/$_[0]/w1_slave") or return "-1";
	@temp = <$fh>;
	close($fh);

        if(  !($temp[0] =~ m\YES\) ){
                return 'U';
        }
	elsif( !($temp[1] =~ m\t=(.*)\) ){
		return 'U';
	}
	elsif($1 < -55000 || $1 > 125000){
		return 'U';
	}
	else{
		$curTemp = $1/1000;
		if($debug >= 1){
			system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp >> $LogPath/ds1820_$_[0]");

        		open ($fh, "+>>$LogPath/ds1820_debug_$_[0]") || die "cant open file $LogPath/ds1820_debug_$_[0]: $!\n";
		        print $fh @temp;
			close $fh;
			if($debug >=2){
				print "\t\tgetTempDS1820 $curTemp\n";
			}
		}

		return $curTemp;
	}
}

#** @function public fillArray ($func, $count, $tolerance, $sensorID])
# @brief XXX
# @param required $func $_[0] sensor function which will be called 
# @param required $count $_[1] count ... XXX
# @param required $tolerance $_[2] NOT IN USE
# @param required $sleep $_[3] delay between measure
# @param optional $sensorID $_[4] ID or GPIO of sensor
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub fillArray{
	my $i;
	#** @var @temperature stores multible temperatures
	my @temperature;
	#** @var @humidity stores multible hydro values 
	my @humidity;
	
	my $curHydro;

	for($i=0; $i<$_[1]; $i++){
		# if temperature+humidity
		if( ($_[0]) eq (\&getDHT11) ){
			($temperature[$i], $humidity[$i]) = $_[0]($_[4]);
		}
		# if Temperature
		else{
			$temperature[$i] = $_[0]($_[4]);
		}
		sleep($_[3]);
	}
	

	if( ($_[0]) eq (\&getDHT11) ){
		return ( avgTemp(\@temperature), avgTemp(\@humidity) );
	}
	else{
		return avgTemp(\@temperature);;
	}
}



#** @function public avgTemp (@array)
# @brief get DS1820 temperature 
# @param required @array $_[0] 
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub avgTemp{
	my @array = @{$_[0]};

my $pos=0;
while (defined $array[$pos]){
        if ($array[$pos] =~ m/U/ ){
                splice(@array, $pos, 1);
        }
        else{   
                $pos++;
        }
}

if( !(defined $array[0]) ){
        return 'U';
}
return mean(@array);
}

1;

