#include "base_transform.h"
#include "base_texture.h"
#include "base_light.h"
#include "base_math.h"
#include "base_shadow.h"

struct VS_INPUT
{
	float4 vLocalPosition 	: POSITION;
	float2 vUv			 	: TEXCOORD0;
};

// -----------------------------------------------------------------
// output descs
// -----------------------------------------------------------------
struct VS_OUTPUT
{
    float4 vPosition  		: SV_Position;
};

Texture2DArray	taCascades		: register( t0 );
Texture2D		tDepth			: register( t1 );


// -------------------------------------------------------------------
// vertex functions
// -------------------------------------------------------------------

VS_OUTPUT mainVS( VS_INPUT input )
{
	VS_OUTPUT output;
	output.vPosition = float4( input.vLocalPosition.xy * 2.0 - 1.0, 1.0, 1.0 );

    return output;
};

float mainPS( VS_OUTPUT input ) : SV_Target0
{
	float2 dims = getDims( tDepth );
	float2 uvAligned = input.vPosition.xy / dims;

	float fDepth = PointSampleCC( tDepth, uvAligned ).r;

	float3 vViewSpacePosition = depthAndUvToViewPosition( fDepth, uvAligned, projectionToView );
	float3 vWorldSpacePosition = mul( viewToWorld, float4( vViewSpacePosition, 1.0 ) ).xyz;

	uint iCascadeIndex = selectCascadeFromWorldPosition( vWorldSpacePosition );

	if( iCascadeIndex < 4 )
	{
		float4 vClipSpace = calculateClipSpacePos( iCascadeIndex, vWorldSpacePosition );

		float fTargetDepth = LinearSampleArrayCC( taCascades, vClipSpace.xy, iCascadeIndex ).r;

		float fThisDepth = vClipSpace.z;

		if( vClipSpace.x > 1.0 || vClipSpace.x < 0.0f ) fTargetDepth = 1.0;
		if( vClipSpace.y > 1.0 || vClipSpace.y < 0.0f ) fTargetDepth = 1.0;

		const float Bias = 2.0 / 65535.0;

		float fBiasMultiplier = pow( 2.0, iCascadeIndex );

		return fTargetDepth > ( fThisDepth - ( Bias * fBiasMultiplier ) ) ? 1.0 : 0.0;
	}
	return 1.0f;
}
